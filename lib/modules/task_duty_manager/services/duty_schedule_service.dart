import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/duty_schedule_model.dart';
import '../constants/duty_constants.dart';

/// Handles all Firestore reads and writes for the [duty_schedules] collection.
class DutyScheduleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _col = 'duty_schedules';

  // ── Schedule Streams ─────────────────────────────────────────

  /// Real-time stream of the schedule for a specific duty type and week.
  /// Returns null if no schedule exists for that week yet.
  Stream<DutyScheduleModel?> streamScheduleForWeek(
      String dutyType, DateTime weekStart) {
    final startTs = Timestamp.fromDate(
        DateTime(weekStart.year, weekStart.month, weekStart.day));
    return _db
        .collection(_col)
        .where('dutyType', isEqualTo: dutyType)
        .where('weekStart', isEqualTo: startTs)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return DutyScheduleModel.fromMap(
          snap.docs.first.data(), snap.docs.first.id);
    });
  }

  /// Real-time stream of all PUBLISHED schedules for the given week.
  /// Used by the Principal dashboard to show the full duty roster.
  Stream<List<DutyScheduleModel>> streamPublishedSchedulesForWeek(
      DateTime weekStart) {
    final startTs = Timestamp.fromDate(
        DateTime(weekStart.year, weekStart.month, weekStart.day));
    return _db
        .collection(_col)
        .where('weekStart', isEqualTo: startTs)
        .where('status', isEqualTo: 'Published')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => DutyScheduleModel.fromMap(d.data(), d.id))
            .toList());
  }

  // ── Teacher View ─────────────────────────────────────────────

  /// One-shot fetch of a schedule (used by the editor so live stream
  /// updates cannot overwrite in-progress edits).
  Future<DutyScheduleModel?> getScheduleForWeek(
      String dutyType, DateTime weekStart) async {
    final startTs = Timestamp.fromDate(
        DateTime(weekStart.year, weekStart.month, weekStart.day));
    final snap = await _db
        .collection(_col)
        .where('dutyType', isEqualTo: dutyType)
        .where('weekStart', isEqualTo: startTs)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return DutyScheduleModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }


  /// Fetches all duty assignments for a teacher on today's date.
  /// Returns a list of maps: { scheduleId, dutyType, zone, date }
  Future<List<Map<String, dynamic>>> getTodayAssignmentsForTeacher(
      String teacherId) async {
    final now = DateTime.now();
    final weekStart = DutyScheduleModel.weekStartFor(now);
    final dayName = _weekdayName(now.weekday);

    // Assembly uses a different key (week label), not a day name.
    // For Phase 1 we only handle daily duties here; Assembly is handled
    // by the schedule editor in Phase 2.
    final snap = await _db
        .collection(_col)
        .where('weekStart',
            isEqualTo: Timestamp.fromDate(
                DateTime(weekStart.year, weekStart.month, weekStart.day)))
        .where('status', isEqualTo: 'Published')
        .get();

    final assignments = <Map<String, dynamic>>[];

    for (final doc in snap.docs) {
      final schedule = DutyScheduleModel.fromMap(doc.data(), doc.id);
      final dayData = schedule.assignments[dayName] ?? {};
      for (final zone in dayData.keys) {
        final teachers = dayData[zone] ?? [];
        if (teachers.contains(teacherId)) {
          assignments.add({
            'scheduleId': schedule.id,
            'dutyType': schedule.dutyType,
            'zone': zone,
            'date': now,
          });
        }
      }
    }

    return assignments;
  }

  // ── Mutations ────────────────────────────────────────────────

  /// Upserts a schedule document. Returns the document ID.
  /// If [schedule.id] is empty a new document is created.
  Future<String> saveSchedule(DutyScheduleModel schedule) async {
    if (schedule.id.isEmpty) {
      final ref = await _db.collection(_col).add(schedule.toMap());
      return ref.id;
    } else {
      await _db.collection(_col).doc(schedule.id).set(schedule.toMap());
      return schedule.id;
    }
  }

  /// Updates only the status field on an existing schedule document.
  Future<void> updateScheduleStatus(String scheduleId, String status) async {
    await _db.collection(_col).doc(scheduleId).update({'status': status});
  }

  // ── Phase 2 principal schedule methods ──────────────────────

  /// Fetch the schedule document for a specific week and duty type.
  Future<DutyScheduleModel?> getWeekSchedule(DateTime weekStart, String dutyType) async {
    return getScheduleForWeek(dutyType, weekStart);
  }

  /// Write/update a single cell assignment in Firestore.
  /// If teacherName is empty, removes assignments for that zone/role.
  Future<void> assignTeacher(
    DateTime weekStart,
    String dutyType,
    String day,
    String zone,
    String teacherName,
  ) async {
    // 1. Get existing schedule if any
    var schedule = await getScheduleForWeek(dutyType, weekStart);

    // 2. Prepare the assignments map
    final Map<String, Map<String, List<String>>> updatedAssignments = 
        schedule != null 
            ? Map<String, Map<String, List<String>>>.from(
                schedule.assignments.map((k, v) => MapEntry(k, Map<String, List<String>>.from(v))))
            : {};

    if (!updatedAssignments.containsKey(day)) {
      updatedAssignments[day] = {};
    }

    final maxTeachers = DutyConstants.getMaxTeachers(zone);

    if (teacherName.isEmpty || teacherName == 'Unassigned') {
      updatedAssignments[day]!.remove(zone);
    } else {
      if (maxTeachers == 1) {
        updatedAssignments[day]![zone] = [teacherName];
      } else {
        final currentList = List<String>.from(updatedAssignments[day]![zone] ?? []);
        if (currentList.contains(teacherName)) {
          currentList.remove(teacherName);
        } else {
          if (currentList.length < maxTeachers) {
            currentList.add(teacherName);
          } else {
            // Replace the last one if full
            currentList[currentList.length - 1] = teacherName;
          }
        }
        if (currentList.isEmpty) {
          updatedAssignments[day]!.remove(zone);
        } else {
          updatedAssignments[day]![zone] = currentList;
        }
      }
    }

    if (schedule != null) {
      final updated = schedule.copyWith(assignments: updatedAssignments);
      await saveSchedule(updated);
    } else {
      final newSchedule = DutyScheduleModel(
        id: '',
        dutyType: dutyType,
        weekStart: weekStart,
        weekEnd: DutyScheduleModel.weekEndFor(weekStart),
        generatedAt: DateTime.now(),
        generatedBy: 'Principal', // default placeholder
        status: 'Draft',
        assignments: updatedAssignments,
      );
      await saveSchedule(newSchedule);
    }
  }

  /// Write/update multiple teacher assignments at once for a single cell in Firestore.
  Future<void> assignTeachersList(
    DateTime weekStart,
    String dutyType,
    String day,
    String zone,
    List<String> teacherIds,
  ) async {
    var schedule = await getScheduleForWeek(dutyType, weekStart);

    final Map<String, Map<String, List<String>>> updatedAssignments = 
        schedule != null 
            ? Map<String, Map<String, List<String>>>.from(
                schedule.assignments.map((k, v) => MapEntry(k, Map<String, List<String>>.from(v))))
            : {};

    if (!updatedAssignments.containsKey(day)) {
      updatedAssignments[day] = {};
    }

    if (teacherIds.isEmpty) {
      updatedAssignments[day]!.remove(zone);
    } else {
      updatedAssignments[day]![zone] = teacherIds;
    }

    if (schedule != null) {
      final updated = schedule.copyWith(assignments: updatedAssignments);
      await saveSchedule(updated);
    } else {
      final newSchedule = DutyScheduleModel(
        id: '',
        dutyType: dutyType,
        weekStart: weekStart,
        weekEnd: DutyScheduleModel.weekEndFor(weekStart),
        generatedAt: DateTime.now(),
        generatedBy: 'Principal',
        status: 'Draft',
        assignments: updatedAssignments,
      );
      await saveSchedule(newSchedule);
    }
  }

  /// Query [leave_requests] where leaveStatus/status is approved and the date matches.
  Future<List<Map<String, dynamic>>> getApprovedLeavesForDate(DateTime date) async {
    final checkDate = DateTime(date.year, date.month, date.day);
    
    // Fetch all leaves that are approved
    final snap = await _db
        .collection('leave_requests')
        .where('status', isEqualTo: 'Approved')
        .get();

    final results = <Map<String, dynamic>>[];

    for (final doc in snap.docs) {
      final data = doc.data();
      final uid = data['userId'] as String? ?? data['teacherId'] as String? ?? '';
      if (uid.isEmpty) continue;

      // Handle startDate/endDate or leaveDate
      DateTime? start;
      DateTime? end;

      if (data['startDate'] != null) {
        start = (data['startDate'] as Timestamp).toDate();
      }
      if (data['endDate'] != null) {
        end = (data['endDate'] as Timestamp).toDate();
      }
      if (data['leaveDate'] != null) {
        start = (data['leaveDate'] as Timestamp).toDate();
        end = start;
      }

      if (start != null && end != null) {
        final startDay = DateTime(start.year, start.month, start.day);
        final endDay = DateTime(end.year, end.month, end.day);

        if (!checkDate.isBefore(startDay) && !checkDate.isAfter(endDay)) {
          results.add({
            'teacherId': uid,
            'teacherName': data['teacherName'] ?? '',
            'leaveDate': data['leaveDate'] ?? data['startDate'],
            'leaveStatus': data['status'] ?? 'Approved',
          });
        }
      }
    }

    return results;
  }

  /// One-shot fetch of all PUBLISHED schedules for a given week.
  Future<List<DutyScheduleModel>> getPublishedSchedulesForWeekOnce(
      DateTime weekStart) async {
    final startTs = Timestamp.fromDate(
        DateTime(weekStart.year, weekStart.month, weekStart.day));
    final snap = await _db
        .collection(_col)
        .where('weekStart', isEqualTo: startTs)
        .where('status', isEqualTo: 'Published')
        .get();
    return snap.docs
        .map((d) => DutyScheduleModel.fromMap(d.data(), d.id))
        .toList();
  }

  // ── Private helpers ──────────────────────────────────────────

  static String _weekdayName(int weekday) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return days[weekday - 1];
  }

  /// Fetches all approved leave requests covering Monday to Friday of the week starting at [weekStart].
  /// Returns a map of day names (Monday to Friday) to lists of teacher UIDs on leave.
  ///
  /// Field priority mirrors rotation_service.dart and getApprovedLeavesForDate:
  ///   - UID field:    'userId' first, fallback to 'teacherId'
  ///   - Status field: 'status' (Approved) first, fallback to 'leaveStatus' (approved)
  ///   - Date field:   'leaveDate' (single day), then 'startDate'/'endDate' (range)
  Future<Map<String, List<String>>> getApprovedLeavesForWeek(DateTime weekStart) async {
    // Two-pass fetch: try status == 'Approved' (capital A, used by leave module)
    // then also try leaveStatus == 'approved' (lowercase, legacy field name)
    final snapApproved = await _db
        .collection('leave_requests')
        .where('status', isEqualTo: 'Approved')
        .get();
    final snapLegacy = await _db
        .collection('leave_requests')
        .where('leaveStatus', isEqualTo: 'approved')
        .get();

    // Merge both result sets, deduplicated by document ID
    final Map<String, Map<String, dynamic>> allDocs = {};
    for (final doc in snapApproved.docs) {
      allDocs[doc.id] = doc.data();
    }
    for (final doc in snapLegacy.docs) {
      allDocs.putIfAbsent(doc.id, () => doc.data());
    }

    debugPrint('[LeavesForWeek] Total approved leave docs found: ${allDocs.length}');

    final result = <String, List<String>>{
      'Monday': [],
      'Tuesday': [],
      'Wednesday': [],
      'Thursday': [],
      'Friday': [],
    };

    for (final entry in allDocs.entries) {
      final data = entry.value;

      // Read UID: userId first (matches rotation_service.dart), then teacherId
      final uid = data['userId'] as String?
          ?? data['teacherId'] as String?
          ?? data['uid'] as String?
          ?? '';
      if (uid.isEmpty) {
        debugPrint('[LeavesForWeek] Skipping doc ${entry.key} — no UID field found. Keys: ${data.keys.toList()}');
        continue;
      }

      // Read dates: leaveDate (single day) → startDate/endDate (range)
      DateTime? start;
      DateTime? end;

      if (data['leaveDate'] != null) {
        start = (data['leaveDate'] as Timestamp).toDate();
        end = start;
      } else {
        if (data['startDate'] != null) {
          start = (data['startDate'] as Timestamp).toDate();
        }
        if (data['endDate'] != null) {
          end = (data['endDate'] as Timestamp).toDate();
        }
      }

      if (start == null && end == null) {
        debugPrint('[LeavesForWeek] Skipping doc ${entry.key} (uid=$uid) — no date fields. Keys: ${data.keys.toList()}');
        continue;
      }

      start ??= end;
      end ??= start;

      final startDay = DateTime(start!.year, start.month, start.day);
      final endDay = DateTime(end!.year, end.month, end.day);

      debugPrint('[LeavesForWeek] uid=$uid leave: $startDay → $endDay');

      for (int i = 0; i < 5; i++) {
        final dayDate = weekStart.add(Duration(days: i));
        final checkDate = DateTime(dayDate.year, dayDate.month, dayDate.day);

        if (!checkDate.isBefore(startDay) && !checkDate.isAfter(endDay)) {
          final dayName = DutyConstants.weekdays[i];
          if (!result[dayName]!.contains(uid)) {
            result[dayName]!.add(uid);
            debugPrint('[LeavesForWeek] Added uid=$uid to $dayName');
          }
        }
      }
    }

    debugPrint('[LeavesForWeek] Final result: $result');
    return result;
  }
}
