import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/training_model.dart';
import '../services/training_service.dart';

class TrainingProvider extends ChangeNotifier {
  final TrainingService _service = TrainingService();
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Stream<List<TrainingModel>> streamAllTrainings() {
    return _service.streamAllTrainings();
  }

  Stream<List<TrainingModel>> streamTeacherTrainings(String teacherId) {
    return _service.streamTeacherTrainings(teacherId);
  }

  Future<bool> addTraining(TrainingModel training) async {
    _setLoading(true);
    try {
      await _service.addTraining(training);
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false, e.toString());
      return false;
    }
  }

  Future<bool> updateTraining(TrainingModel training) async {
    _setLoading(true);
    try {
      await _service.updateTraining(training);
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false, e.toString());
      return false;
    }
  }

  Future<bool> deleteTraining(String id) async {
    _setLoading(true);
    try {
      await _service.deleteTraining(id);
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false, e.toString());
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