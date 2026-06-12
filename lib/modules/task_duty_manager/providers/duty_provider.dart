import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/duty_schedule_model.dart';
import '../models/checklist_log_model.dart';
import '../services/duty_schedule_service.dart';
import '../services/checklist_service.dart';
import '../services/rotation_service.dart';
import '../../auth/models/user_model.dart';

/// Single ChangeNotifier provider that wires together all three
/// Task & Duty Manager services, following the same pattern as
/// [LeaveProvider] and [AuthProvider] in this project.
class DutyProvider extends ChangeNotifier {
  final DutyScheduleService _scheduleService = DutyScheduleService();
  final ChecklistService _checklistService = ChecklistService();
  final RotationService _rotationService = RotationService();

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ── Schedule ─────────────────────────────────────────────────

  /// Real-time stream of a schedule for a duty type + week.
  Stream<DutyScheduleModel?> streamScheduleForWeek(
          String dutyType, DateTime weekStart) =>
      _scheduleService.streamScheduleForWeek(dutyType, weekStart);

  /// One-shot fetch used by the schedule editor.
  Future<DutyScheduleModel?> getScheduleForWeek(
          String dutyType, DateTime weekStart) =>
      _scheduleService.getScheduleForWeek(dutyType, weekStart);

  /// Real-time stream of all published schedules for a week.
  Stream<List<DutyScheduleModel>> streamPublishedSchedulesForWeek(
          DateTime weekStart) =>
      _scheduleService.streamPublishedSchedulesForWeek(weekStart);

  /// Returns today's duty assignments for a teacher.
  Future<List<Map<String, dynamic>>> getTodayAssignments(String teacherId) =>
      _scheduleService.getTodayAssignmentsForTeacher(teacherId);

  /// Saves (creates or updates) a duty schedule as Draft.
  Future<bool> saveSchedule(DutyScheduleModel schedule) async {
    _setLoading(true);
    try {
      await _scheduleService.saveSchedule(schedule);
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('Save Schedule Error: $e');
      _setLoading(false, e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  /// Publishes a schedule (status Draft → Published) and updates
  /// the rotation tracker so fairness counts stay accurate.
  Future<bool> confirmAndPublishSchedule(DutyScheduleModel schedule) async {
    _setLoading(true);
    try {
      // First save any unsaved changes
      final id = await _scheduleService.saveSchedule(schedule);
      // Update status
      await _scheduleService.updateScheduleStatus(id, 'Published');
      // Increment rotation counts
      final published = schedule.copyWith(status: 'Published');
      await _rotationService.updateTracker(published);
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('Publish Schedule Error: $e');
      _setLoading(false, e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  // ── Checklist ────────────────────────────────────────────────

  /// Real-time stream of a teacher's checklist log for one zone.
  Stream<ChecklistLogModel?> streamChecklistLog({
    required String teacherId,
    required String scheduleId,
    required String zone,
  }) =>
      _checklistService.streamChecklistLog(
          teacherId: teacherId, scheduleId: scheduleId, zone: zone);

  /// Real-time stream of all checklist logs for a given date.
  Stream<List<ChecklistLogModel>> streamLogsForDate(DateTime date) =>
      _checklistService.streamLogsForDate(date);

  /// Gets or creates the checklist log for a Cleaning Duty zone,
  /// pre-populating all items from DutyConstants.
  Future<String?> initChecklistLog({
    required String teacherId,
    required String scheduleId,
    required String dutyType,
    required String zone,
    required DateTime assignedDate,
  }) async {
    try {
      return await _checklistService.getOrCreateChecklistLog(
        teacherId: teacherId,
        scheduleId: scheduleId,
        dutyType: dutyType,
        zone: zone,
        assignedDate: assignedDate,
      );
    } catch (e) {
      debugPrint('Init Checklist Log Error: $e');
      return null;
    }
  }

  /// Updates a single checkbox in a Cleaning Duty checklist.
  Future<bool> updateChecklistItem({
    required String logId,
    required String item,
    required bool checked,
    required Map<String, bool> currentItems,
  }) async {
    try {
      await _checklistService.updateChecklistItem(
        logId: logId,
        item: item,
        checked: checked,
        currentItems: currentItems,
      );
      return true;
    } catch (e) {
      debugPrint('Checklist Update Error: $e');
      return false;
    }
  }

  /// Marks a non-Cleaning duty as Done (single toggle).
  Future<bool> markAsDone({
    required String teacherId,
    required String scheduleId,
    required String dutyType,
    required String zone,
    required DateTime assignedDate,
  }) async {
    try {
      await _checklistService.markAsDone(
        teacherId: teacherId,
        scheduleId: scheduleId,
        dutyType: dutyType,
        zone: zone,
        assignedDate: assignedDate,
      );
      return true;
    } catch (e) {
      debugPrint('Mark As Done Error: $e');
      return false;
    }
  }

  // ── Rotation / Teacher Pool ───────────────────────────────────

  /// Returns teachers who are active and not on approved leave today.
  Future<List<UserModel>> getAvailableTeachers(DateTime date) =>
      _rotationService.getAvailableTeachers(date);

  /// Returns Map<dayName, Set<uid>> for the full week — one Firestore query.
  Future<Map<String, Set<String>>> getOnLeaveMapForWeek(DateTime weekStart) =>
      _rotationService.getOnLeaveMapForWeek(weekStart);

  /// Returns all active teachers (for the schedule editor picker).
  Future<List<UserModel>> getAllTeachers() =>
      _rotationService.getActiveTeachers();

  // ── Error Handling ────────────────────────────────────────────

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
