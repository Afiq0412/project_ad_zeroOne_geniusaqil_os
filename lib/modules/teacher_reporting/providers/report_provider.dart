import 'package:flutter/foundation.dart';
import '../models/report_model.dart';
import '../services/report_service.dart';

class ReportProvider extends ChangeNotifier {
  final ReportService _service = ReportService();

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Stream teacher's own reports
  Stream<List<ReportModel>> streamMyReports(String userId) =>
      _service.streamMyReports(userId);

  /// Stream all reports for admin
  Stream<List<ReportModel>> streamAllReports() =>
      _service.streamAllReports();

  /// Submit report
  Future<bool> submitReport({
    required String reporterId,
    required String reporterName,
    required String category,
    required String description,
    String? evidenceUrl,
  }) async {
    _setLoading(true);
    try {
      final report = ReportModel(
        id: '',
        reporterId: reporterId,
        reporterName: reporterName,
        category: category,
        description: description,
        status: 'Pending',
        createdAt: DateTime.now(),
        evidenceUrl: evidenceUrl,
      );
      await _service.submitReport(report);
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('Submit report error: $e');
      _setLoading(false, e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  /// Admin updates report status
  Future<bool> updateStatus({
    required String reportId,
    required String status,
    String? adminNote,
  }) async {
    _setLoading(true);
    try {
      await _service.updateReportStatus(
        reportId: reportId,
        status: status,
        adminNote: adminNote,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false, e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  /// Delete report
  Future<bool> deleteReport(String reportId) async {
    _setLoading(true);
    try {
      await _service.deleteReport(reportId);
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false, e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _setLoading(bool value, [String? error]) {
    _isLoading = value;
    _errorMessage = error;
    notifyListeners();
  }
}
