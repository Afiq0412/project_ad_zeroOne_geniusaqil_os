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

  /// Creates a new checklist log document from a model.
  Future<String> _createChecklistLogModel(ChecklistLogModel log) async {
    final ref = await _db.collection(_col).add(log.toMap());
    return ref.id;
  }

  /// Fetches an existing checklist log document for a specific teacher, zone, duty type, and date.
  Future<ChecklistLogModel?> getChecklistLog(
    String teacherId,
    String zone,
    String dutyType,
    DateTime date,
  ) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final snap = await _db
        .collection(_col)
        .where('teacherId', isEqualTo: teacherId)
        .where('zone', isEqualTo: zone)
        .where('dutyType', isEqualTo: dutyType)
        .where('assignedDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('assignedDate', isLessThan: Timestamp.fromDate(end))
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return ChecklistLogModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }

  /// Updates a single checkbox item in an existing log document.
  /// Also updates status and timestamps atomically.
  Future<void> updateChecklistItem(String logId, String item, bool isChecked) async {
    final doc = await _db.collection(_col).doc(logId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final rawItems = data['items'] as Map<String, dynamic>? ?? {};
    final currentItems = rawItems.map((k, v) => MapEntry(k, (v as bool?) ?? false));

    final updatedItems = Map<String, bool>.from(currentItems)..[item] = isChecked;
    final newStatus = ChecklistLogModel.deriveStatus(updatedItems);
    final now = Timestamp.fromDate(DateTime.now());

    final update = <String, dynamic>{
      'items.$item': isChecked,
      'status': newStatus,
    };

    final wasEmpty = currentItems.values.every((v) => !v);
    if (isChecked && wasEmpty) update['startedAt'] = now;
    if (newStatus == 'Completed') update['completedAt'] = now;

    await _db.collection(_col).doc(logId).update(update);
  }

  /// Creates a new log document with all items set to false.
  Future<String> createChecklistLog(
    String teacherId,
    String teacherName,
    String zone,
    String dutyType,
    DateTime date,
    List<String> items,
  ) async {
    final Map<String, bool> itemsMap = {
      for (final item in items) item: false,
    };
    final docRef = await _db.collection(_col).add({
      'scheduleId': '',
      'teacherId': teacherId,
      'teacherName': teacherName,
      'zone': zone,
      'dutyType': dutyType,
      'assignedDate': Timestamp.fromDate(date),
      'items': itemsMap,
      'status': 'Pending',
    });
    return docRef.id;
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

    return _createChecklistLogModel(log);
  }

  /// Marks a duty as Done with a single toggle (for non-Cleaning duties).
  /// Creates the log if it doesn't exist, or updates the existing one.
  Future<void> markAsDone(String teacherId, String zone, String dutyType, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final snap = await _db
        .collection(_col)
        .where('teacherId', isEqualTo: teacherId)
        .where('zone', isEqualTo: zone)
        .where('dutyType', isEqualTo: dutyType)
        .where('assignedDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('assignedDate', isLessThan: Timestamp.fromDate(end))
        .limit(1)
        .get();

    final now = Timestamp.fromDate(DateTime.now());

    if (snap.docs.isEmpty) {
      await _db.collection(_col).add({
        'scheduleId': '',
        'teacherId': teacherId,
        'teacherName': '',
        'dutyType': dutyType,
        'zone': zone,
        'assignedDate': Timestamp.fromDate(date),
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
