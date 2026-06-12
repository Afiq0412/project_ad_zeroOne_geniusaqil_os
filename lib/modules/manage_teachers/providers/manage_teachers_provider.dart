import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/teacher_manage_model.dart';
import '../services/manage_teachers_service.dart';

class ManageTeachersProvider extends ChangeNotifier {
  final ManageTeachersService _service = ManageTeachersService();

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Returns a real-time stream of active Teacher-role users.
  Stream<List<TeacherManageModel>> streamTeachers() {
    return _service.streamTeachers();
  }

  /// Soft-removes a teacher (role → "Removed", status → "inactive").
  /// Returns true on success, false on failure.
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
