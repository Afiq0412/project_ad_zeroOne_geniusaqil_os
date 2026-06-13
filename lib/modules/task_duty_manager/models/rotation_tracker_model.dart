import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks cumulative assignment counts per teacher per duty-type per zone.
/// Used by the auto-assign algorithm to ensure fair rotation.
class RotationTrackerModel {
  final String id;
  final String teacherId;
  final String dutyType;
  final String zone;
  final int totalAssignments;
  final DateTime? lastAssignedDate;

  RotationTrackerModel({
    required this.id,
    required this.teacherId,
    required this.dutyType,
    required this.zone,
    required this.totalAssignments,
    this.lastAssignedDate,
  });

  factory RotationTrackerModel.fromMap(Map<String, dynamic> data, String documentId) {
    return RotationTrackerModel(
      id: documentId,
      teacherId: data['teacherId'] as String? ?? '',
      dutyType: data['dutyType'] as String? ?? '',
      zone: data['zone'] as String? ?? '',
      totalAssignments: (data['totalAssignments'] as int?) ?? 0,
      lastAssignedDate: data['lastAssignedDate'] != null
          ? (data['lastAssignedDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'dutyType': dutyType,
      'zone': zone,
      'totalAssignments': totalAssignments,
      if (lastAssignedDate != null)
        'lastAssignedDate': Timestamp.fromDate(lastAssignedDate!),
    };
  }
}
