import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/duty_schedule_model.dart';

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

  // ── Private helpers ──────────────────────────────────────────

  static String _weekdayName(int weekday) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return days[weekday - 1];
  }
}
