import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks a teacher's checklist completion for one duty zone on one day.
///
/// For Cleaning Duty: [items] holds each checklist task → checked state.
/// For other duties:  [items] is empty; completion is stored via [status] = 'Completed'.
class ChecklistLogModel {
  final String id;
  final String scheduleId;
  final String teacherId;
  final String dutyType;
  final String zone;
  final DateTime assignedDate;

  /// { "Sweep the assembly hall floor": true, "Mop the floor": false, ... }
  /// Empty map for non-Cleaning duty types.
  final Map<String, bool> items;

  /// 'Pending' | 'InProgress' | 'Completed'
  final String status;

  final DateTime? startedAt;
  final DateTime? completedAt;

  ChecklistLogModel({
    required this.id,
    required this.scheduleId,
    required this.teacherId,
    required this.dutyType,
    required this.zone,
    required this.assignedDate,
    required this.items,
    required this.status,
    this.startedAt,
    this.completedAt,
  });

  factory ChecklistLogModel.fromMap(Map<String, dynamic> data, String documentId) {
    final rawItems = data['items'] as Map<String, dynamic>? ?? {};
    final items = rawItems.map((k, v) => MapEntry(k, (v as bool?) ?? false));

    return ChecklistLogModel(
      id: documentId,
      scheduleId: data['scheduleId'] as String? ?? '',
      teacherId: data['teacherId'] as String? ?? '',
      dutyType: data['dutyType'] as String? ?? '',
      zone: data['zone'] as String? ?? '',
      assignedDate: (data['assignedDate'] as Timestamp).toDate(),
      items: items,
      status: data['status'] as String? ?? 'Pending',
      startedAt: data['startedAt'] != null
          ? (data['startedAt'] as Timestamp).toDate()
          : null,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scheduleId': scheduleId,
      'teacherId': teacherId,
      'dutyType': dutyType,
      'zone': zone,
      'assignedDate': Timestamp.fromDate(assignedDate),
      'items': items,
      'status': status,
      if (startedAt != null) 'startedAt': Timestamp.fromDate(startedAt!),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
    };
  }

  // ── Status derivation ────────────────────────────────────────

  /// Derives the correct status string from the current [items] map.
  /// Used after every checkbox update to keep status in sync.
  static String deriveStatus(Map<String, bool> items) {
    if (items.isEmpty) return 'Pending';
    final checked = items.values.where((v) => v).length;
    if (checked == 0) return 'Pending';
    if (checked == items.length) return 'Completed';
    return 'InProgress';
  }

  /// Returns how many checklist items are checked vs total.
  String get progressLabel {
    if (items.isEmpty) return status;
    final checked = items.values.where((v) => v).length;
    return '$checked / ${items.length}';
  }

  /// 0.0–1.0 progress value for a progress indicator.
  double get progressFraction {
    if (items.isEmpty) return status == 'Completed' ? 1.0 : 0.0;
    if (items.isEmpty) return 0.0;
    return items.values.where((v) => v).length / items.length;
  }
}
