import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/report_model.dart';

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'reports';

  /// Stream all reports by a specific teacher
  Stream<List<ReportModel>> streamMyReports(String userId) {
    return _db
        .collection(_collection)
        .where('reporterId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final reports = snap.docs
          .map((d) => ReportModel.fromMap(d.data(), d.id))
          .toList();
      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reports;
    });
  }

  /// Stream ALL reports — for admin/principal
  Stream<List<ReportModel>> streamAllReports() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReportModel.fromMap(d.data(), d.id))
            .toList());
  }

  /// Submit a new report
  Future<void> submitReport(ReportModel report) async {
    try {
      await _db.collection(_collection).add(report.toMap());
    } catch (e) {
      debugPrint('ReportService.submitReport error: $e');
      throw Exception('Failed to submit report: $e');
    }
  }

  /// Admin updates status and adds a note
  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    String? adminNote,
  }) async {
    try {
      final Map<String, dynamic> update = {'status': status};
      if (adminNote != null) update['adminNote'] = adminNote;
      if (status == 'Resolved') {
        update['resolvedAt'] = Timestamp.fromDate(DateTime.now());
      }
      await _db.collection(_collection).doc(reportId).update(update);
    } catch (e) {
      throw Exception('Failed to update report: $e');
    }
  }

  /// Delete a report
  Future<void> deleteReport(String reportId) async {
    try {
      await _db.collection(_collection).doc(reportId).delete();
    } catch (e) {
      throw Exception('Failed to delete report: $e');
    }
  }
}
