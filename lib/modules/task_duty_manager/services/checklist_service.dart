import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/checklist_log_model.dart';
import '../constants/duty_constants.dart';

/// Handles all Firestore reads and writes for the [checklist_logs] collection.
class ChecklistService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _col = 'checklist_logs';

  // ── Streams ──────────────────────────────────────────────────

  /// Real-time stream of a teacher's checklist log for a given
  /// schedule + zone. Returns null if the log does not exist yet.
  Stream<ChecklistLogModel?> streamChecklistLog({
    required String teacherId,
    required String scheduleId,
    required String zone,
  }) {
    return _db
        .collection(_col)
        .where('teacherId', isEqualTo: teacherId)
        .where('scheduleId', isEqualTo: scheduleId)
        .where('zone', isEqualTo: zone)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return ChecklistLogModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
    });
  }

  /// Real-time stream of all logs for a given date.
  /// Used by the Principal dashboard to show completion status.
  Stream<List<ChecklistLogModel>> streamLogsForDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return _db
        .collection(_col)
        .where('assignedDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('assignedDate', isLessThan: Timestamp.fromDate(dayEnd))
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChecklistLogModel.fromMap(d.data(), d.id)).toList());
  }

  // ── Mutations ────────────────────────────────────────────────

  /// Creates a new checklist log document. Called on the teacher's first
  /// interaction with their checklist (lazy creation pattern).
  Future<String> createChecklistLog(ChecklistLogModel log) async {
    final ref = await _db.collection(_col).add(log.toMap());
    return ref.id;
  }

  /// Updates a single checkbox item in an existing log document.
  /// Also updates status and timestamps atomically.
  Future<void> updateChecklistItem({
    required String logId,
    required String item,
    required bool checked,
    required Map<String, bool> currentItems,
  }) async {
    final updatedItems = Map<String, bool>.from(currentItems)..[item] = checked;
    final newStatus = ChecklistLogModel.deriveStatus(updatedItems);
    final now = Timestamp.fromDate(DateTime.now());

    final update = <String, dynamic>{
      'items.$item': checked,
      'status': newStatus,
    };

    // Set startedAt on first check, completedAt when all done.
    final wasEmpty = currentItems.values.every((v) => !v);
    if (checked && wasEmpty) update['startedAt'] = now;
    if (newStatus == 'Completed') update['completedAt'] = now;

    await _db.collection(_col).doc(logId).update(update);
  }

  /// Creates or initialises a checklist log with all items from [DutyConstants].
  /// Call this when a teacher opens a Cleaning Duty checklist for the first time.
  Future<String> getOrCreateChecklistLog({
    required String teacherId,
    required String scheduleId,
    required String dutyType,
    required String zone,
    required DateTime assignedDate,
  }) async {
    // Check if log already exists
    final snap = await _db
        .collection(_col)
        .where('teacherId', isEqualTo: teacherId)
        .where('scheduleId', isEqualTo: scheduleId)
        .where('zone', isEqualTo: zone)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) return snap.docs.first.id;

    // Create with all checklist items pre-populated as unchecked
    final items = <String, bool>{};
    for (final item in DutyConstants.getChecklistItems(zone)) {
      items[item] = false;
    }

    final log = ChecklistLogModel(
      id: '',
      scheduleId: scheduleId,
      teacherId: teacherId,
      dutyType: dutyType,
      zone: zone,
      assignedDate: assignedDate,
      items: items,
      status: 'Pending',
    );

    return createChecklistLog(log);
  }

  /// Marks a duty as Done with a single toggle (for non-Cleaning duties).
  /// Creates the log if it doesn't exist, or updates the existing one.
  Future<void> markAsDone({
    required String teacherId,
    required String scheduleId,
    required String dutyType,
    required String zone,
    required DateTime assignedDate,
  }) async {
    final snap = await _db
        .collection(_col)
        .where('teacherId', isEqualTo: teacherId)
        .where('scheduleId', isEqualTo: scheduleId)
        .where('zone', isEqualTo: zone)
        .limit(1)
        .get();

    final now = Timestamp.fromDate(DateTime.now());

    if (snap.docs.isEmpty) {
      await _db.collection(_col).add({
        'scheduleId': scheduleId,
        'teacherId': teacherId,
        'dutyType': dutyType,
        'zone': zone,
        'assignedDate': Timestamp.fromDate(assignedDate),
        'items': <String, bool>{},
        'status': 'Completed',
        'startedAt': now,
        'completedAt': now,
      });
    } else {
      await _db.collection(_col).doc(snap.docs.first.id).update({
        'status': 'Completed',
        'completedAt': now,
      });
    }
  }
}
