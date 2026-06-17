import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents one week's duty schedule for a single duty type.
///
/// [assignments] layout:
///   Daily duties: `{ "Monday": { "Assembly Hall": ["uid1"], "Dining Area": ["uid1","uid2"] } }`
///   Assembly duty: `{ "weekLabel": { "Sub Theme": ["Theme Text"], "Introduction": ["uid1"], ... } }`
class DutyScheduleModel {
  final String id;
  final String dutyType;
  final DateTime weekStart; // Monday 00:00 of the scheduled week
  final DateTime weekEnd;   // Friday 23:59 of the scheduled week
  final DateTime generatedAt;
  final String generatedBy; // UID of the principal who created it
  final String status;      // 'Draft' | 'Published'

  /// Map[dayOrWeekLabel, Map[zone, List[teacherUids]]]
  final Map<String, Map<String, List<String>>> assignments;

  DutyScheduleModel({
    required this.id,
    required this.dutyType,
    required this.weekStart,
    required this.weekEnd,
    required this.generatedAt,
    required this.generatedBy,
    required this.status,
    required this.assignments,
  });

  factory DutyScheduleModel.fromMap(Map<String, dynamic> data, String documentId) {
    final rawAssignments = data['assignments'] as Map<String, dynamic>? ?? {};
    final assignments = <String, Map<String, List<String>>>{};

    for (final dayKey in rawAssignments.keys) {
      final dayData = rawAssignments[dayKey] as Map<String, dynamic>? ?? {};
      assignments[dayKey] = {};
      for (final zoneKey in dayData.keys) {
        final val = dayData[zoneKey];
        if (val is List) {
          assignments[dayKey]![zoneKey] = List<String>.from(val);
        } else if (val is String) {
          // Backward-compat: stored as single string
          assignments[dayKey]![zoneKey] = [val];
        } else {
          assignments[dayKey]![zoneKey] = [];
        }
      }
    }

    return DutyScheduleModel(
      id: documentId,
      dutyType: data['dutyType'] as String? ?? '',
      weekStart: (data['weekStart'] as Timestamp).toDate(),
      weekEnd: (data['weekEnd'] as Timestamp).toDate(),
      generatedAt: (data['generatedAt'] as Timestamp).toDate(),
      generatedBy: data['generatedBy'] as String? ?? '',
      status: data['status'] as String? ?? 'Draft',
      assignments: assignments,
    );
  }

  Map<String, dynamic> toMap() {
    // Serialise assignments: List<String> → native Firestore array
    final rawAssignments = <String, dynamic>{};
    for (final dayKey in assignments.keys) {
      rawAssignments[dayKey] = <String, dynamic>{};
      for (final zoneKey in assignments[dayKey]!.keys) {
        (rawAssignments[dayKey] as Map<String, dynamic>)[zoneKey] =
            assignments[dayKey]![zoneKey];
      }
    }

    return {
      'dutyType': dutyType,
      'weekStart': Timestamp.fromDate(weekStart),
      'weekEnd': Timestamp.fromDate(weekEnd),
      'generatedAt': Timestamp.fromDate(generatedAt),
      'generatedBy': generatedBy,
      'status': status,
      'assignments': rawAssignments,
    };
  }

  DutyScheduleModel copyWith({
    String? status,
    Map<String, Map<String, List<String>>>? assignments,
  }) {
    return DutyScheduleModel(
      id: id,
      dutyType: dutyType,
      weekStart: weekStart,
      weekEnd: weekEnd,
      generatedAt: generatedAt,
      generatedBy: generatedBy,
      status: status ?? this.status,
      assignments: assignments ?? this.assignments,
    );
  }

  // ── Utility helpers ──────────────────────────────────────────

  /// Returns the Monday of whatever week [date] falls in.
  static DateTime weekStartFor(DateTime date) {
    final diff = date.weekday - DateTime.monday;
    final monday = DateTime(date.year, date.month, date.day - diff);
    return monday;
  }

  /// Returns the Friday 23:59:59 of whatever week [date] falls in.
  static DateTime weekEndFor(DateTime date) {
    final monday = weekStartFor(date);
    return monday.add(const Duration(days: 4, hours: 23, minutes: 59, seconds: 59));
  }
}
