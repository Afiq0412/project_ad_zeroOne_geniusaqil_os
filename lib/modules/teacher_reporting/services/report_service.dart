import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/report_model.dart';

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'reports';

  /// Uploads an evidence file to Firebase Storage.
  Future<String?> uploadFile(
    Uint8List fileBytes,
    String reporterId,
    String filename,
  ) async {
    try {
      Reference ref = _storage.ref().child('report_evidence/$reporterId/$filename');
      SettableMetadata metadata = SettableMetadata(
        contentType: _contentTypeFor(filename),
      );
      UploadTask uploadTask = ref.putData(fileBytes, metadata);
      TaskSnapshot snapshot = await uploadTask.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
            'Upload timed out. If testing on Web (Chrome), this is likely due to missing CORS configuration on Firebase Storage. Please check cors.json in the project root.',
          );
        },
      );
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading evidence: $e");
      rethrow;
    }
  }

  String _contentTypeFor(String filename) {
    final lowerName = filename.toLowerCase();
    if (lowerName.endsWith('.pdf')) return 'application/pdf';
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerName.endsWith('.doc')) return 'application/msword';
    if (lowerName.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return 'application/octet-stream';
  }

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
      if (report.id.isNotEmpty) {
        await _db.collection(_collection).doc(report.id).set(report.toMap());
      } else {
        await _db.collection(_collection).add(report.toMap());
      }
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
