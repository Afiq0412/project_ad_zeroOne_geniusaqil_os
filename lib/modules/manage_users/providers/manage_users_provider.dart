import 'package:flutter/foundation.dart';
import '../../auth/models/user_model.dart';
import '../services/manage_users_service.dart';

class ManageUsersProvider extends ChangeNotifier {
  final ManageUsersService _service = ManageUsersService();

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Returns a real-time stream of all users in the system.
  Stream<List<UserModel>> streamUsers() {
    return _service.streamUsers();
  }

  /// Returns a real-time stream of the audit logs timeline.
  Stream<List<Map<String, dynamic>>> streamAuditLogs() {
    return _service.streamAuditLogs();
  }

  /// Updates profile details in Firestore.
  Future<bool> updateUserProfile({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required String role,
    required String status,
    required UserModel changedBy,
  }) async {
    _setLoading(true);
    try {
      await _service.updateUserProfile(
        uid: uid,
        name: name,
        email: email,
        phone: phone,
        role: role,
        status: status,
        changedBy: changedBy,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false, e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  /// Promotes an Intern to Teacher.
  Future<bool> assignInternAsTeacher({
    required String uid,
    required String name,
    required UserModel changedBy,
  }) async {
    _setLoading(true);
    try {
      await _service.assignInternAsTeacher(
        uid: uid,
        name: name,
        changedBy: changedBy,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false, e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  /// Activates or deactivates a user account.
  Future<bool> toggleAccountStatus({
    required String uid,
    required String name,
    required String currentStatus,
    required UserModel changedBy,
  }) async {
    _setLoading(true);
    try {
      await _service.toggleAccountStatus(
        uid: uid,
        name: name,
        currentStatus: currentStatus,
        changedBy: changedBy,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false, e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  /// Triggers a secure password reset email.
  Future<bool> sendPasswordReset({
    required String email,
    required String targetUserId,
    required String targetUserName,
    required UserModel changedBy,
  }) async {
    _setLoading(true);
    try {
      await _service.sendPasswordReset(
        email: email,
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        changedBy: changedBy,
      );
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
