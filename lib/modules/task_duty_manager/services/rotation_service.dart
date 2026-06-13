import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/duty_constants.dart';
import '../models/rotation_tracker_model.dart';
import '../models/duty_schedule_model.dart';
import '../../auth/models/user_model.dart';

/// Handles the auto-assign fairness algorithm and the rotation tracker.
///
/// The algorithm (Phase 4) will call:
///   1. [getAvailableTeachers] — pool filtered by leave
///   2. [getTrackerForDutyType] — load fairness counts
///   3. [sortByFairness] — rank teachers per zone
///   4. [updateTracker] — commit counts after schedule is confirmed
class RotationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _trackerCol = 'duty_rotation_tracker';

  /// Single-query approach: loads all approved leaves once and returns
  /// Map[dayName, Set[teacherUid]] for the 5 days of [weekStart]'s week.
  /// Far more efficient than calling getTeachersOnLeave 5 separate times.
  Future<Map<String, Set<String>>> getOnLeaveMapForWeek(DateTime weekStart) async {
    final snap = await _db
        .collection('leave_requests')
        .where('status', isEqualTo: 'Approved')
        .get();

    // Pre-fill with empty sets for every weekday
    final result = <String, Set<String>>{
      for (final day in DutyConstants.weekdays) day: <String>{},
    };

    for (final doc in snap.docs) {
      final data = doc.data();
      final uid = data['userId'] as String? ?? '';
      if (uid.isEmpty) continue;

      final start = (data['startDate'] as Timestamp).toDate();
      final end   = (data['endDate']   as Timestamp).toDate();

      for (int i = 0; i < DutyConstants.weekdays.length; i++) {
        final date    = weekStart.add(Duration(days: i));
        final dayDate = DateTime(date.year, date.month, date.day);
        final startDay = DateTime(start.year, start.month, start.day);
        final endDay   = DateTime(end.year,   end.month,   end.day);

        if (!dayDate.isBefore(startDay) && !dayDate.isAfter(endDay)) {
          result[DutyConstants.weekdays[i]]!.add(uid);
        }
      }
    }

    return result;
  }

  // ── Teacher Pool ─────────────────────────────────────────────

  /// Fetches all users with role == "Teacher" from Firestore.
  Future<List<UserModel>> getActiveTeachers() async {
    final snap =
        await _db.collection('users').where('role', isEqualTo: 'Teacher').get();
    return snap.docs
        .map((d) => UserModel.fromMap(d.data(), d.id))
        .toList();
  }

  /// Returns the set of teacher UIDs who have an APPROVED leave on [date].
  /// Reads directly from the existing [leave_requests] collection —
  /// no cross-module coupling, just a Firestore query.
  Future<Set<String>> getTeachersOnLeave(DateTime date) async {
    final snap = await _db
        .collection('leave_requests')
        .where('status', isEqualTo: 'Approved')
        .get();

    final onLeave = <String>{};
    final checkDate = DateTime(date.year, date.month, date.day);

    for (final doc in snap.docs) {
      final data = doc.data();
      final uid = data['userId'] as String? ?? '';
      if (uid.isEmpty) continue;

      final start = (data['startDate'] as Timestamp).toDate();
      final end = (data['endDate'] as Timestamp).toDate();
      final startDay = DateTime(start.year, start.month, start.day);
      final endDay = DateTime(end.year, end.month, end.day);

      if (!checkDate.isBefore(startDay) && !checkDate.isAfter(endDay)) {
        onLeave.add(uid);
      }
    }

    return onLeave;
  }

  /// Returns teachers who are active AND not on approved leave on [date].
  Future<List<UserModel>> getAvailableTeachers(DateTime date) async {
    final all = await getActiveTeachers();
    final onLeave = await getTeachersOnLeave(date);
    return all.where((t) => !onLeave.contains(t.id)).toList();
  }

  // ── Rotation Tracker ─────────────────────────────────────────

  /// Loads all tracker entries for a given duty type.
  Future<List<RotationTrackerModel>> getTrackerForDutyType(
      String dutyType) async {
    final snap = await _db
        .collection(_trackerCol)
        .where('dutyType', isEqualTo: dutyType)
        .get();
    return snap.docs
        .map((d) => RotationTrackerModel.fromMap(d.data(), d.id))
        .toList();
  }

  // ── Fairness Sort ────────────────────────────────────────────

  /// Sorts [available] teachers by fairness for a specific [dutyType] + [zone]:
  ///   Primary sort:   totalAssignments ASC (fewest first)
  ///   Tie-break sort: lastAssignedDate ASC (longest ago first)
  ///   Never assigned: treated as highest priority (count = 0, date = null)
  List<UserModel> sortByFairness({
    required List<UserModel> available,
    required List<RotationTrackerModel> tracker,
    required String dutyType,
    required String zone,
  }) {
    // Build lookup keyed by teacherId for this specific zone
    final lookup = <String, RotationTrackerModel>{};
    for (final t in tracker) {
      if (t.zone == zone) lookup[t.teacherId] = t;
    }

    return List<UserModel>.from(available)
      ..sort((a, b) {
        final aEntry = lookup[a.id];
        final bEntry = lookup[b.id];

        final aCount = aEntry?.totalAssignments ?? 0;
        final bCount = bEntry?.totalAssignments ?? 0;
        if (aCount != bCount) return aCount.compareTo(bCount);

        // Tie-break: whoever hasn't been assigned recently goes first
        final aDate = aEntry?.lastAssignedDate;
        final bDate = bEntry?.lastAssignedDate;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return -1; // Never assigned → top priority
        if (bDate == null) return 1;
        return aDate.compareTo(bDate);
      });
  }

  // ── Tracker Update ───────────────────────────────────────────

  /// After a schedule is confirmed/published, increments [totalAssignments]
  /// and updates [lastAssignedDate] for every teacher in the schedule.
  /// Uses a Firestore batch for atomicity.
  ///
  /// Note: Assembly 'Sub Theme' slots store text values, not teacher UIDs —
  /// those are skipped automatically by the UID lookup below.
  Future<void> updateTracker(DutyScheduleModel schedule) async {
    final batch = _db.batch();
    final now = Timestamp.fromDate(DateTime.now());

    // Collect all (zone, teacherId) pairs from the schedule
    for (final dayKey in schedule.assignments.keys) {
      for (final zone in schedule.assignments[dayKey]!.keys) {
        final teacherIds = schedule.assignments[dayKey]![zone] ?? [];
        for (final uid in teacherIds) {
          if (uid.isEmpty) continue;

          // Check if tracker entry already exists
          final snap = await _db
              .collection(_trackerCol)
              .where('teacherId', isEqualTo: uid)
              .where('dutyType', isEqualTo: schedule.dutyType)
              .where('zone', isEqualTo: zone)
              .limit(1)
              .get();

          if (snap.docs.isEmpty) {
            final ref = _db.collection(_trackerCol).doc();
            batch.set(ref, {
              'teacherId': uid,
              'dutyType': schedule.dutyType,
              'zone': zone,
              'totalAssignments': 1,
              'lastAssignedDate': now,
            });
          } else {
            final doc = snap.docs.first;
            final current = (doc.data()['totalAssignments'] as int?) ?? 0;
            batch.update(doc.reference, {
              'totalAssignments': current + 1,
              'lastAssignedDate': now,
            });
          }
        }
      }
    }

    await batch.commit();
  }

  /// Fetches all documents from duty_rotation_tracker.
  Future<List<RotationTrackerModel>> getRotationData() async {
    final snap = await _db.collection(_trackerCol).get();
    return snap.docs
        .map((d) => RotationTrackerModel.fromMap(d.data(), d.id))
        .toList();
  }

  /// Loops through all assignments in a published schedule and increments tracker counts.
  Future<void> updateRotationAfterPublish(
      Map assignments, String dutyType, DateTime weekStart) async {
    for (final dayKey in assignments.keys) {
      final dayData = assignments[dayKey];
      if (dayData is! Map) continue;

      final offset = _dayOffset(dayKey.toString());
      final assignedDate = weekStart.add(Duration(days: offset));

      for (final zoneKey in dayData.keys) {
        final zone = zoneKey.toString();
        // Skip assembly sub theme as it is text, not a teacher UID
        if (dutyType == DutyConstants.assembly && zone == DutyConstants.assemblySubThemeKey) {
          continue;
        }

        final val = dayData[zoneKey];
        if (val is List) {
          for (final item in val) {
            final uid = item.toString().trim();
            if (uid.isNotEmpty && uid != 'Unassigned' && uid != 'UNASSIGNED') {
              await upsertTrackerRecord(uid, dutyType, zone, assignedDate);
            }
          }
        } else if (val is String) {
          final uid = val.trim();
          if (uid.isNotEmpty && uid != 'Unassigned' && uid != 'UNASSIGNED') {
            await upsertTrackerRecord(uid, dutyType, zone, assignedDate);
          }
        }
      }
    }
  }

  /// Creates or updates a single tracker document.
  Future<void> upsertTrackerRecord(
      String teacherId, String dutyType, String zone, DateTime assignedDate) async {
    final snap = await _db
        .collection(_trackerCol)
        .where('teacherId', isEqualTo: teacherId)
        .where('dutyType', isEqualTo: dutyType)
        .where('zone', isEqualTo: zone)
        .limit(1)
        .get();

    final now = Timestamp.fromDate(assignedDate);

    if (snap.docs.isEmpty) {
      await _db.collection(_trackerCol).add({
        'teacherId': teacherId,
        'dutyType': dutyType,
        'zone': zone,
        'totalAssignments': 1,
        'lastAssignedDate': now,
      });
    } else {
      final doc = snap.docs.first;
      final current = (doc.data()['totalAssignments'] as int?) ?? 0;
      await doc.reference.update({
        'totalAssignments': current + 1,
        'lastAssignedDate': now,
      });
    }
  }

  int _dayOffset(String dayName) {
    switch (dayName) {
      case 'Monday': return 0;
      case 'Tuesday': return 1;
      case 'Wednesday': return 2;
      case 'Thursday': return 3;
      case 'Friday': return 4;
      default: return 0;
    }
  }
}
