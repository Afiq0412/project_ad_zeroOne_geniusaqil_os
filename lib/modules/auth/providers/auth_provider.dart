import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  UserModel? _currentUserModel;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUserModel => _currentUserModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUserModel != null;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null) {
        final userModel = await _authService.getUserDetails(firebaseUser.uid);
        if (userModel != null && userModel.status.toLowerCase() == 'inactive') {
          await _authService.signOut();
          _currentUserModel = null;
          _errorMessage = 'Your account has been deactivated. Please contact the Principal.';
        } else {
          _currentUserModel = userModel;
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      final userModel = await _authService.loginWithEmailAndPassword(email, password);
      if (userModel != null && userModel.status.toLowerCase() == 'inactive') {
        await _authService.signOut();
        _currentUserModel = null;
        _setLoading(false, 'Your account has been deactivated. Please contact the Principal.');
        return false;
      }
      _currentUserModel = userModel;
      _setLoading(false);
      return _currentUserModel != null;
    } catch (e, stacktrace) {
      print('Login Error: $e');
      print(stacktrace);
      _setLoading(false, e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> register(String name, String email, String password, String role) async {
    _setLoading(true);
    try {
      _currentUserModel = await _authService.registerWithEmailAndPassword(name, email, password, role);
      _setLoading(false);
      return _currentUserModel != null;
    } catch (e, stacktrace) {
      print('Registration Error: $e');
      print(stacktrace);
      _setLoading(false, e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    await _authService.signOut();
    _currentUserModel = null;
    _setLoading(false);
  }

  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true);
    try {
      await _authService.sendPasswordResetEmail(email);
      _setLoading(false);
      return true;
    } catch (e, stacktrace) {
      print('Password Reset Error: $e');
      print(stacktrace);
      _setLoading(false, e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<void> refreshUser() async {
    final firebaseUser = _authService.currentUser;
    if (firebaseUser != null) {
      try {
        final userModel = await _authService.getUserDetails(firebaseUser.uid);
        if (userModel != null && userModel.status.toLowerCase() == 'inactive') {
          await _authService.signOut();
          _currentUserModel = null;
          _errorMessage = 'Your account has been deactivated. Please contact the Principal.';
        } else {
          _currentUserModel = userModel;
        }
        notifyListeners();
      } catch (e) {
        print('Error refreshing user: $e');
      }
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
