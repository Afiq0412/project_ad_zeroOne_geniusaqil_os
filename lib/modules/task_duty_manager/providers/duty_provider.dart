import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/duty_schedule_model.dart';
import '../models/checklist_log_model.dart';
import '../services/duty_schedule_service.dart';
import '../services/checklist_service.dart';
import '../services/rotation_service.dart';
import '../services/auto_assign_service.dart';
import '../../auth/models/user_model.dart';
import '../constants/duty_constants.dart';

/// Single ChangeNotifier provider that wires together all three
/// Task & Duty Manager services, following the same pattern as
/// [LeaveProvider] and [AuthProvider] in this project.
class DutyProvider extends ChangeNotifier {
  final DutyScheduleService _scheduleService = DutyScheduleService();
  final ChecklistService _checklistService = ChecklistService();
  final RotationService _rotationService = RotationService();
  final AutoAssignService _autoAssignService = AutoAssignService();

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ── Phase 4 Auto-Assign State ────────────────────────────────
  bool _isGenerating = false;
  List<String> _unassignedSlots = [];

  bool get isGenerating => _isGenerating;
  List<String> get unassignedSlots => _unassignedSlots;

  // ── Day-by-Day Roster State ──────────────────────────────────
  String _selectedDay = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'][
      (DateTime.now().weekday >= 1 && DateTime.now().weekday <= 5)
          ? DateTime.now().weekday - 1
          : 0];
  bool _isGeneratingDay = false;
  List<String> _onLeaveTodayTeachers = [];

  List<String> _onLeaveTodayTeacherUids = [];

  String get selectedDay => _selectedDay;
  bool get isGeneratingDay => _isGeneratingDay;
  List<String> get onLeaveTodayTeachers => _onLeaveTodayTeachers;
  List<String> get onLeaveTodayTeacherUids => _onLeaveTodayTeacherUids;

  // ── Phase 2 Navigation & Schedule State ──────────────────────
  static DateTime _getDefaultWeekStart() {
    final now = DateTime.now();
    final todayWeekStart = DutyScheduleModel.weekStartFor(now);
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      return todayWeekStart.add(const Duration(days: 7));
    }
    return todayWeekStart;
  }

  DateTime _currentWeekStart = _getDefaultWeekStart();
  String _selectedDutyType = DutyConstants.cleaning;
  DutyScheduleModel? _weekSchedule;
  Map<String, DutyScheduleModel?> _allSchedules = {};
  Map<String, DutyScheduleModel?> get allSchedules => _allSchedules;

  // ── Phase 3 Today Duties & Checklist State ───────────────────
  List<Map<String, dynamic>> _todayDuties = [];
  ChecklistLogModel? _currentChecklistLog;
  StreamSubscription<ChecklistLogModel?>? _checklistSubscription;

  List<Map<String, dynamic>> get todayDuties => _todayDuties;
  ChecklistLogModel? get currentChecklistLog => _currentChecklistLog;

  DateTime get currentWeekStart => _currentWeekStart;
  String get selectedDutyType => _selectedDutyType;
  DutyScheduleModel? get weekSchedule => _weekSchedule;

  /// Returns true when the viewed week is before today's week (read-only mode).
  bool get isViewingPastWeek {
    final todayWeekStart = DutyScheduleModel.weekStartFor(DateTime.now());
    return _currentWeekStart.isBefore(todayWeekStart);
  }

  /// Returns true when the viewed week is more than 1 week ahead.
  bool get isViewingFutureWeek {
    final todayWeekStart = DutyScheduleModel.weekStartFor(DateTime.now());
    final nextWeekStart = todayWeekStart.add(const Duration(days: 7));
    return _currentWeekStart.isAfter(nextWeekStart);
  }

  /// Convenience alias — past weeks are view-only.
  bool get isReadOnly => isViewingPastWeek;

  set currentWeekStart(DateTime val) {
    _currentWeekStart = val;
    notifyListeners();
  }

  set selectedDutyType(String val) {
    _selectedDutyType = val;
    notifyListeners();
  }

  Future<void> loadWeekSchedule() async {
    _isLoading = true;
    notifyListeners();
    try {
      final Map<String, DutyScheduleModel?> newSchedules = {};
      for (final type in DutyConstants.allDutyTypes) {
        final sched = await _scheduleService.getWeekSchedule(_currentWeekStart, type);
        newSchedules[type] = sched;
      }
      _allSchedules = newSchedules;
      _weekSchedule = _allSchedules[_selectedDutyType];
      _errorMessage = null;
    } catch (e) {
      debugPrint('Load Week Schedule Error: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void nextWeek() {
    final todayWeekStart = DutyScheduleModel.weekStartFor(DateTime.now());
    final nextWeekStart = todayWeekStart.add(const Duration(days: 7));
    // Block navigation beyond next week
    if (!_currentWeekStart.isBefore(nextWeekStart)) return;
    _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
    loadWeekSchedule();
    setSelectedDay(_selectedDay);
  }

  void previousWeek() {
    final todayWeekStart = DutyScheduleModel.weekStartFor(DateTime.now());
    // Block navigation before current week
    if (!_currentWeekStart.isAfter(todayWeekStart)) return;
    _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
    loadWeekSchedule();
    setSelectedDay(_selectedDay);
  }

  Future<bool> assignTeacher(String day, String zone, String teacherName) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _scheduleService.assignTeacher(_currentWeekStart, _selectedDutyType, day, zone, teacherName);
      await loadWeekSchedule();
      return true;
    } catch (e) {
      debugPrint('Assign Teacher Error: $e');
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> assignTeachersList(String day, String zone, List<String> teacherIds) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _scheduleService.assignTeachersList(_currentWeekStart, _selectedDutyType, day, zone, teacherIds);
      await loadWeekSchedule();
      return true;
    } catch (e) {
      debugPrint('Assign Teachers List Error: $e');
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectDutyType(String dutyType) {
    _selectedDutyType = dutyType;
    loadWeekSchedule();
  }

  // ── Phase 3 Today Duties & Checklist Methods ─────────────────

  Future<void> loadTodayDuties(String teacherId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      final weekStart = DutyScheduleModel.weekStartFor(now);
      final dayName = _weekdayName(now.weekday);

      final schedules = await _scheduleService.getPublishedSchedulesForWeekOnce(weekStart);
      final List<Map<String, dynamic>> duties = [];

      for (final schedule in schedules) {
        final dayKey = schedule.dutyType == DutyConstants.assembly ? 'Monday' : dayName;
        if (schedule.dutyType == DutyConstants.assembly && now.weekday != DateTime.monday) {
          continue;
        }

        final dayData = schedule.assignments[dayKey] ?? {};
        for (final zone in dayData.keys) {
          final assignedList = dayData[zone] ?? [];
          if (assignedList.contains(teacherId)) {
            duties.add({
              'scheduleId': schedule.id,
              'dutyType': schedule.dutyType,
              'zone': zone,
              'day': dayKey,
              'date': now,
              'timeSlot': DutyConstants.timeSlot(schedule.dutyType),
              'assignedTeachers': assignedList,
            });
          }
        }
      }
      _todayDuties = duties;
      _errorMessage = null;
    } catch (e) {
      debugPrint('Load Today Duties Error: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadChecklistLog({
    required String teacherId,
    required String teacherName,
    required String zone,
    required String dutyType,
    required DateTime date,
    required String scheduleId,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _checklistSubscription?.cancel();

      if (DutyConstants.hasChecklist(dutyType, zone)) {
        await _checklistService.getOrCreateChecklistLog(
          teacherId: teacherId,
          scheduleId: scheduleId,
          dutyType: dutyType,
          zone: zone,
          assignedDate: date,
        );
      }

      _checklistSubscription = _checklistService
          .streamChecklistLog(
            teacherId: teacherId,
            scheduleId: scheduleId,
            zone: zone,
          )
          .listen((log) {
        _currentChecklistLog = log;
        notifyListeners();
      });

      _errorMessage = null;
    } catch (e) {
      debugPrint('Load Checklist Log Error: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleChecklistItem(String item, bool value) async {
    if (_currentChecklistLog == null) return;
    try {
      await _checklistService.updateChecklistItem(
        _currentChecklistLog!.id,
        item,
        value,
      );
    } catch (e) {
      debugPrint('Toggle Checklist Item Error: $e');
    }
  }

  Future<void> markAsDoneForCurrent() async {
    if (_currentChecklistLog == null) return;
    try {
      await _checklistService.markAsDone(
        _currentChecklistLog!.teacherId,
        _currentChecklistLog!.zone,
        _currentChecklistLog!.dutyType,
        _currentChecklistLog!.assignedDate,
      );
    } catch (e) {
      debugPrint('Mark As Done Error: $e');
    }
  }

  static String _weekdayName(int weekday) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return days[weekday - 1];
  }

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
      await _rotationService.updateRotationAfterPublish(
          schedule.assignments, schedule.dutyType, schedule.weekStart);
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('Publish Schedule Error: $e');
      _setLoading(false, e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  /// Compatibility forwarder for publishSchedule.
  Future<bool> publishSchedule(DutyScheduleModel schedule) async {
    return confirmAndPublishSchedule(schedule);
  }

  String get weeklyStatus {
    for (final type in DutyConstants.allDutyTypes) {
      final sched = _allSchedules[type];
      if (sched == null || sched.status != 'Published') {
        return 'Draft';
      }
    }
    return 'Published';
  }

  /// Returns the publication status of next week's schedules.
  /// 'empty' = nothing planned, 'draft' = some/all are draft, 'published' = all published.
  Future<String> getNextWeekStatus() async {
    try {
      final todayWeekStart = DutyScheduleModel.weekStartFor(DateTime.now());
      final nextWeekStart = todayWeekStart.add(const Duration(days: 7));
      int publishedCount = 0;
      int existingCount = 0;
      for (final type in DutyConstants.allDutyTypes) {
        final sched = await _scheduleService.getWeekSchedule(nextWeekStart, type);
        if (sched != null) {
          existingCount++;
          if (sched.status == 'Published') publishedCount++;
        }
      }
      if (existingCount == 0) return 'empty';
      if (publishedCount == DutyConstants.allDutyTypes.length) return 'published';
      return 'draft';
    } catch (e) {
      debugPrint('getNextWeekStatus error: $e');
      return 'empty';
    }
  }

  Future<bool> publishAllSchedules() async {
    _isLoading = true;
    notifyListeners();
    try {
      for (final type in DutyConstants.allDutyTypes) {
        final schedule = _allSchedules[type];
        if (schedule != null) {
          if (schedule.status != 'Published') {
            await confirmAndPublishSchedule(schedule);
          }
        } else {
          final newSchedule = DutyScheduleModel(
            id: '',
            dutyType: type,
            weekStart: _currentWeekStart,
            weekEnd: DutyScheduleModel.weekEndFor(_currentWeekStart),
            generatedAt: DateTime.now(),
            generatedBy: 'Principal',
            status: 'Draft',
            assignments: {},
          );
          await confirmAndPublishSchedule(newSchedule);
        }
      }
      await loadWeekSchedule();
      return true;
    } catch (e) {
      debugPrint('Publish All Schedules Error: $e');
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Auto-generates weekly assignments using fairness algorithm and saves them as drafts.
  Future<void> generateAndSaveSchedule(DateTime weekStart) async {
    _isGenerating = true;
    _unassignedSlots = [];
    notifyListeners();
    try {
      final List<String> allUnassigned = [];
      for (final day in DutyConstants.weekdays) {
        final unassigned = await _autoAssignService.generateForDay(weekStart, day);
        allUnassigned.addAll(unassigned.map((s) => '$day - $s'));
      }
      _unassignedSlots = allUnassigned;

      // Refresh currently loaded week schedule
      await loadWeekSchedule();
      _errorMessage = null;
    } catch (e) {
      debugPrint('Generate and Save Schedule Error: $e');
      _errorMessage = e.toString();
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Auto-generates assignments for ONE specific day only across all 5 duty types.
  Future<void> generateForDay(DateTime weekStart, String dayName) async {
    _isGeneratingDay = true;
    _unassignedSlots = [];
    notifyListeners();
    try {
      final unassigned = await _autoAssignService.generateForDay(weekStart, dayName);
      _unassignedSlots = unassigned;
      // Refresh currently loaded week schedule
      await loadWeekSchedule();
      // Reload leave data for this day
      final dayOffset = _dayOffset(dayName);
      final targetDate = weekStart.add(Duration(days: dayOffset));
      await loadOnLeaveTeachersForDay(targetDate);
      _errorMessage = null;
    } catch (e) {
      debugPrint('Generate For Day Error: $e');
      _errorMessage = e.toString();
    } finally {
      _isGeneratingDay = false;
      notifyListeners();
    }
  }

  /// Updates selected day and reloads duty cards and leave data for that day.
  Future<void> setSelectedDay(String dayName) async {
    _selectedDay = dayName;
    notifyListeners();
    final dayOffset = _dayOffset(dayName);
    final targetDate = _currentWeekStart.add(Duration(days: dayOffset));
    await loadOnLeaveTeachersForDay(targetDate);
  }

  /// Queries leave_requests for approved leaves on that date, resolves teacher names from users collection.
  Future<void> loadOnLeaveTeachersForDay(DateTime date) async {
    try {
      final leaves = await _scheduleService.getApprovedLeavesForDate(date);
      final activeTeachers = await _rotationService.getActiveTeachers();
      final Map<String, String> teacherNames = {
        for (final t in activeTeachers) t.id: t.name,
      };

      final List<String> names = [];
      final List<String> uids = [];
      for (final l in leaves) {
        final uid = l['teacherId'] as String? ?? '';
        if (uid.isNotEmpty && !uids.contains(uid)) {
          uids.add(uid);
        }
        final storedName = l['teacherName'] as String? ?? '';
        final resolvedName = teacherNames[uid] ?? storedName;
        if (resolvedName.isNotEmpty && !names.contains(resolvedName)) {
          names.add(resolvedName);
        }
      }
      _onLeaveTodayTeachers = names;
      _onLeaveTodayTeacherUids = uids;
      notifyListeners();
    } catch (e) {
      debugPrint('Load On Leave Teachers For Day Error: $e');
    }
  }

  int _dayOffset(String dayName) {
    switch (dayName) {
      case 'Monday': return 0;
      case 'Tuesday': return 1;
      case 'Wednesday': return 2;
      case 'Thursday': return 3;
      case 'Friday': return 4;
      default: return 0;
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
      await _checklistService.updateChecklistItem(logId, item, checked);
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
      await _checklistService.markAsDone(teacherId, zone, dutyType, assignedDate);
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

  /// Returns Map[dayName, Set[uid]] for the full week — one Firestore query.
  Future<Map<String, Set<String>>> getOnLeaveMapForWeek(DateTime weekStart) =>
      _rotationService.getOnLeaveMapForWeek(weekStart);

  /// Returns all active teachers (for the schedule editor picker).
  Future<List<UserModel>> getAllTeachers() =>
      _rotationService.getActiveTeachers();

  /// Returns approved leaves for a specific date.
  Future<List<Map<String, dynamic>>> getApprovedLeavesForDate(DateTime date) =>
      _scheduleService.getApprovedLeavesForDate(date);

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

  @override
  void dispose() {
    _checklistSubscription?.cancel();
    super.dispose();
  }
}
