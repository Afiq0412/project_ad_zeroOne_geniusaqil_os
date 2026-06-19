import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/teacher_manage_model.dart';
import '../services/manage_teachers_service.dart';

class ManageTeachersProvider extends ChangeNotifier {
  final ManageTeachersService _service = ManageTeachersService();

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<String?> uploadDocument(
    String userId,
    String slot,
    Uint8List fileBytes,
    String filename,
  ) {
    return _service.uploadFile(userId, slot, fileBytes, filename);
  }

  Stream<List<TeacherManageModel>> streamTeachers() {
    return _service.streamTeachers();
  }

  Stream<TeacherManageModel?> streamTeacher(String uid) {
    return _service.streamTeacher(uid);
  }

  /// Saves the Module-1 record fields (info + document checklist).
  Future<bool> saveRecord(String uid, Map<String, dynamic> recordData) async {
    _setLoading(true);
    try {
      await _service.updateTeacherRecord(uid, recordData);
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('Save Record Error: $e');
      _setLoading(false, e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  /// Soft-removes a teacher.
  Future<bool> removeTeacher(String uid) async {
    _setLoading(true);
    try {
      await _service.removeTeacher(uid);
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('Remove Teacher Error: $e');
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
