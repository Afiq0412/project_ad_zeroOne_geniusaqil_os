import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String reporterId;
  final String reporterName;
  final String category;
  final String description;
  final String status; // 'Pending', 'In Review', 'Resolved'
  final DateTime createdAt;
  final String? evidenceUrl;
  final String? adminNote;
  final DateTime? resolvedAt;

  ReportModel({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
    this.evidenceUrl,
    this.adminNote,
    this.resolvedAt,
  });

  /// All report categories from the PDF, plus a general option.
  static const List<String> categories = [
    'Sexual Harassment Report',
    'Bullying Report (Physical/Emotional/Social Media)',
    'Conflict between Staff Report',
    'SOP Violation Report',
    'Workload Stress Report',
    'Teacher Misconduct Report',
    'Facility Maintenance Report',
    'Teaching Material Shortage Report',
    'Safety Hazard Report',
    'IT/System Problem Report',
    'Other',
  ];

  /// Icon per category
  static const Map<String, String> categoryIcons = {
    'Sexual Harassment Report': 'warning',
    'Bullying Report (Physical/Emotional/Social Media)': 'report',
    'Conflict between Staff Report': 'people',
    'SOP Violation Report': 'gavel',
    'Workload Stress Report': 'psychology',
    'Teacher Misconduct Report': 'person_off',
    'Facility Maintenance Report': 'build',
    'Teaching Material Shortage Report': 'inventory',
    'Safety Hazard Report': 'health_and_safety',
    'IT/System Problem Report': 'computer',
    'Other': 'more_horiz',
  };

  /// True if category is sensitive (harassment, bullying, misconduct)
  bool get isSensitive => [
        'Sexual Harassment Report',
        'Bullying Report (Physical/Emotional/Social Media)',
        'Teacher Misconduct Report',
        'Conflict between Staff Report',
      ].contains(category);

  factory ReportModel.fromMap(
      Map<String, dynamic> data, String documentId) {
    final evidenceValue =
        data['evidenceUrl'] ?? data['evidenceLink'] ?? data['fileLink'];

    return ReportModel(
      id: documentId,
      reporterId: data['reporterId'] ?? '',
      reporterName: data['reporterName'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      status: data['status'] ?? 'Pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      evidenceUrl: evidenceValue is String ? evidenceValue : null,
      adminNote: data['adminNote'] as String?,
      resolvedAt: data['resolvedAt'] != null
          ? (data['resolvedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reporterId': reporterId,
      'reporterName': reporterName,
      'category': category,
      'description': description,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'evidenceUrl': evidenceUrl,
      'adminNote': adminNote,
      'resolvedAt':
          resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    };
  }
}
