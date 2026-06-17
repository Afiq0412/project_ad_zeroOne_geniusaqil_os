import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../../leave_management/services/notification_service.dart';

/// Single ChangeNotifier provider that wires together all three
/// Task & Duty Manager services, following the same pattern as
/// [LeaveProvider] and [AuthProvider] in this project.
class DutyProvider extends ChangeNotifier {
  final DutyScheduleService _scheduleService = DutyScheduleService();
  final ChecklistService _checklistService = ChecklistService();
  final RotationService _rotationService = RotationService();
  final AutoAssignService _autoAssignService = AutoAssignService();
  final NotificationService _notificationService = NotificationService();

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ── Phase 4 Auto-Assign State ────────────────────────────────
  bool _isGenerating = false;
  List<String> _unassignedSlots = [];

  bool get isGenerating => _isGenerating;
  List<String> get unassignedSlots => _unassignedSlots;

  // ── Conflict Detection State ─────────────────────────────────
  List<Map<String, dynamic>> _conflictSlots = [];
  bool _hasConflicts = false;
  bool _isCheckingConflicts = false;

  List<Map<String, dynamic>> get conflictSlots => _conflictSlots;
  bool get hasConflicts => _hasConflicts;
  bool get isCheckingConflicts => _isCheckingConflicts;

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

      // Always ensure a log document exists — for Cleaning duties this
      // pre-populates all checklist items; for other duties it creates an empty
      // 'Pending' document so markAsDoneForCurrent() can find it via the stream.
      await _checklistService.getOrCreateChecklistLog(
        teacherId: teacherId,
        scheduleId: scheduleId,
        dutyType: dutyType,
        zone: zone,
        assignedDate: date,
      );

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
      // Use the document ID directly — avoids a stale date-range re-query
      // that can write to a different document than the one the stream watches.
      if (_currentChecklistLog!.id.isNotEmpty) {
        await _checklistService.markAsDoneById(_currentChecklistLog!.id);
      } else {
        // Fallback for edge case where id is unknown (should not happen in normal flow)
        await _checklistService.markAsDone(
          _currentChecklistLog!.teacherId,
          _currentChecklistLog!.zone,
          _currentChecklistLog!.dutyType,
          _currentChecklistLog!.assignedDate,
          scheduleId: _currentChecklistLog!.scheduleId,
        );
      }
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

  /// Checks current and next week schedules for conflicts:
  /// - Teacher assigned to a duty but has approved leave that day
  /// - Days with zero assignments (unplanned)
  /// Only checks published or draft schedules — not empty weeks
  Future<void> checkAndFlagConflicts(DateTime weekStart) async {
    _isCheckingConflicts = true;
    _conflictSlots = [];
    notifyListeners();

    try {
      // Get leave map for the week
      final leavesMap = await _scheduleService.getApprovedLeavesForWeek(weekStart);

      // Get all teachers for name lookup
      final allTeachers = await _rotationService.getActiveTeachers();
      final Map<String, String> teacherNames = {
        for (final t in allTeachers) t.id: t.name,
      };

      final List<Map<String, dynamic>> conflicts = [];

      for (final type in DutyConstants.allDutyTypes) {
        final sched = await _scheduleService.getWeekSchedule(weekStart, type);
        if (sched == null) continue;

        for (final day in DutyConstants.weekdays) {
          // Skip assembly for non-Monday
          if (type == DutyConstants.assembly && day != 'Monday') continue;

          final onLeaveUIDs = leavesMap[day]?.toSet() ?? <String>{};
          final dayData = sched.assignments[day] ?? {};

          for (final zone in DutyConstants.zonesFor(type)) {
            // Skip Sub Theme
            if (type == DutyConstants.assembly &&
                zone == DutyConstants.assemblySubThemeKey) {
              continue;
            }

            final assigned = dayData[zone] ?? [];

            // Check 1: Assigned teacher is on leave
            for (final uid in assigned) {
              if (uid == 'UNASSIGNED' || uid.isEmpty) continue;
              if (onLeaveUIDs.contains(uid)) {
                conflicts.add({
                  'type': 'leave_conflict',
                  'day': day,
                  'zone': zone,
                  'dutyType': type,
                  'teacherId': uid,
                  'teacherName': teacherNames[uid] ?? uid,
                  'message': '${teacherNames[uid] ?? uid} is on leave on $day — $zone needs reassignment',
                });
              }
            }

            // Check 2: Slot is unassigned or empty
            if (assigned.isEmpty || assigned.first == 'UNASSIGNED') {
              conflicts.add({
                'type': 'unassigned',
                'day': day,
                'zone': zone,
                'dutyType': type,
                'message': '$day — ${DutyConstants.displayName(type)}: $zone is unassigned',
              });
            }
          }
        }
      }

      _conflictSlots = conflicts;
      _hasConflicts = conflicts.isNotEmpty;
    } catch (e) {
      debugPrint('Conflict check error: $e');
    } finally {
      _isCheckingConflicts = false;
      notifyListeners();
    }
  }

  /// Auto-generates ONLY for days that have conflicts — preserves clean days
  Future<void> autoFixConflicts(DateTime weekStart) async {
    _isGenerating = true;
    notifyListeners();

    try {
      // Get unique days that have conflicts
      final conflictDays = _conflictSlots
          .map((c) => c['day'] as String)
          .toSet()
          .toList();

      final List<String> allUnassigned = [];
      for (final day in conflictDays) {
        // Only regenerate actionable days (not past days)
        final now = DateTime.now();
        final todayWeekStart = DutyScheduleModel.weekStartFor(now);
        final dayOffset = _dayOffset(day);
        final targetDate = weekStart.add(Duration(days: dayOffset));
        final todayDate = DateTime(now.year, now.month, now.day);
        final targetDateOnly = DateTime(
            targetDate.year, targetDate.month, targetDate.day);

        // Skip past days
        if (weekStart.isAtSameMomentAs(todayWeekStart) &&
            targetDateOnly.isBefore(todayDate)) {
          continue;
        }

        final unassigned = await _autoAssignService.generateForDay(weekStart, day);
        allUnassigned.addAll(unassigned.map((s) => '$day - $s'));
      }

      _unassignedSlots = allUnassigned;
      await loadWeekSchedule();

      // Re-check conflicts after fixing
      await checkAndFlagConflicts(weekStart);
    } catch (e) {
      debugPrint('Auto fix conflicts error: $e');
      _errorMessage = e.toString();
    } finally {
      _isGenerating = false;
      notifyListeners();
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
      await _checklistService.markAsDone(
        teacherId,
        zone,
        dutyType,
        assignedDate,
        scheduleId: scheduleId,
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

  // ── Monthly Performance ───────────────────────────────────────

  // ── Fixed Tracking Start Date ─────────────────────────────────
  //
  // The tracking start date is stored permanently in Firestore under
  // app_config/duty_tracking { trackingStartDate: Timestamp }.
  // The very first call creates this document (set to today), making
  // that date the permanent anchor.  Every subsequent call reads the
  // same value — the data never shifts regardless of when the report
  // is opened.

  /// Reads the permanent tracking start date from Firestore.
  /// Creates the config document with today's date if it does not yet exist.
  Future<DateTime> _getOrCreateTrackingStartDate() async {
    final ref = FirebaseFirestore.instance
        .collection('app_config')
        .doc('duty_tracking');
    final snap = await ref.get();
    if (snap.exists && snap.data()!.containsKey('trackingStartDate')) {
      final ts = snap.data()!['trackingStartDate'];
      if (ts is Timestamp) {
        final dt = ts.toDate();
        return DateTime(dt.year, dt.month, dt.day);
      }
    }
    // Document missing or field missing — bootstrap with today's date.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await ref.set(
      {'trackingStartDate': Timestamp.fromDate(today)},
      SetOptions(merge: true),
    );
    return today;
  }

  List<DateTime> _getWeekStartsInMonth(int year, int month) {
    final List<DateTime> weekStarts = [];
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);

    // Find first Monday of or before the month
    DateTime current = firstDay;
    while (current.weekday != DateTime.monday) {
      current = current.subtract(const Duration(days: 1));
    }

    // Collect all Mondays that overlap with the month
    while (current.isBefore(lastDay) || current.isAtSameMomentAs(lastDay)) {
      if (current.month == month ||
          current.add(const Duration(days: 4)).month == month) {
        weekStarts.add(current);
      }
      current = current.add(const Duration(days: 7));
    }
    return weekStarts;
  }

  /// Fetches monthly performance data for all active teachers.
  ///
  /// Uses a **fixed** tracking start date fetched from Firestore so the
  /// historical view never shifts between logins or days.
  ///
  /// Duty dates before [trackingStartDate] are completely ignored.
  /// Today's incomplete duties are counted as **Pending Today** (amber),
  /// not as Missed or Upcoming.
  ///
  /// The returned list contains an extra top-level entry at index 0 that
  /// is a metadata map: { 'meta': true, 'trackingStartDate': DateTime }.
  /// The view layer reads this before rendering teacher cards.
  Future<List<Map<String, dynamic>>> getMonthlyPerformance(
      int year, int month) async {
    try {
      // ── Step 1: Resolve permanent tracking start date ──────────
      final trackingStartDate = await _getOrCreateTrackingStartDate();

      final allTeachers = await _rotationService.getActiveTeachers();
      final weekStarts = _getWeekStartsInMonth(year, month);

      // ── Step 2: Fetch all published schedules for this month ────
      final List<DutyScheduleModel> publishedSchedules = [];
      for (final weekStart in weekStarts) {
        final weeklySchedules =
            await _scheduleService.getPublishedSchedulesForWeekOnce(weekStart);
        publishedSchedules.addAll(weeklySchedules);
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final List<Map<String, dynamic>> performance = [];

      // ── Step 3: Per-teacher performance calculation ─────────────
      for (final teacher in allTeachers) {
        final logs = await _checklistService.getLogsForTeacherAndMonth(
          teacherId: teacher.id,
          year: year,
          month: month,
        );

        int completedCount = 0;
        int inProgressCount = 0;
        int missedCount = 0;
        int pendingTodayCount = 0; // today's not-yet-done duties
        int upcomingCount = 0;     // future duties
        int totalAssigned = 0;     // only duties on/after trackingStartDate

        final Map<String, Map<String, int>> dutyBreakdown = {
          'Cleaning':    {'assigned': 0, 'completed': 0},
          'Arrival':     {'assigned': 0, 'completed': 0},
          'Dismissal':   {'assigned': 0, 'completed': 0},
          'HalfFullDay': {'assigned': 0, 'completed': 0},
          'Assembly':    {'assigned': 0, 'completed': 0},
        };

        for (final schedule in publishedSchedules) {
          final dutyType = schedule.dutyType;

          for (final dayName in DutyConstants.weekdays) {
            final dayAssignments = schedule.assignments[dayName] ?? {};
            final dayOffset = _dayOffset(dayName);
            final dutyDate = schedule.weekStart.add(Duration(days: dayOffset));

            // Only count duties falling within the target month
            if (dutyDate.year != year || dutyDate.month != month) continue;

            final dutyDateOnly =
                DateTime(dutyDate.year, dutyDate.month, dutyDate.day);

            // ── Fixed tracking gate ─────────────────────────────────
            // Any duty before the tracking start date is completely
            // excluded — as if the feature didn't exist yet.
            if (dutyDateOnly.isBefore(trackingStartDate)) continue;

            for (final zone in dayAssignments.keys) {
              // Skip Assembly Sub Theme text zone
              if (dutyType == DutyConstants.assembly &&
                  zone == DutyConstants.assemblySubThemeKey) continue;

              final assignedTeachers = dayAssignments[zone] ?? [];
              if (!assignedTeachers.contains(teacher.id)) continue;

              totalAssigned++;

              // Find the matching checklist log for this duty
              ChecklistLogModel? matchingLog;
              for (final log in logs) {
                if (log.dutyType == dutyType &&
                    log.zone == zone &&
                    log.assignedDate.year == dutyDate.year &&
                    log.assignedDate.month == dutyDate.month &&
                    log.assignedDate.day == dutyDate.day) {
                  matchingLog = log;
                  break;
                }
              }

              bool isCompleted = false;
              final isToday = dutyDateOnly.isAtSameMomentAs(today);
              final isPast  = dutyDateOnly.isBefore(today);

              if (matchingLog != null &&
                  matchingLog.status == 'Completed') {
                // ✅ Completed — locked in permanently
                completedCount++;
                isCompleted = true;
              } else if (matchingLog != null &&
                  (matchingLog.status == 'InProgress' ||
                   matchingLog.status == 'in_progress')) {
                if (isToday) {
                  // Still in progress today → Pending Today
                  pendingTodayCount++;
                } else if (isPast) {
                  // Was in-progress but the day passed → Missed
                  missedCount++;
                } else {
                  inProgressCount++;
                }
              } else {
                // Pending / no log
                if (isToday) {
                  // Today's day hasn't ended yet → Pending Today (amber)
                  pendingTodayCount++;
                } else if (isPast) {
                  // Day has fully passed without completion → Missed (red)
                  missedCount++;
                } else {
                  // Future date → Upcoming (grey)
                  upcomingCount++;
                }
              }

              // Duty-type breakdown
              if (dutyBreakdown.containsKey(dutyType)) {
                dutyBreakdown[dutyType]!['assigned'] =
                    dutyBreakdown[dutyType]!['assigned']! + 1;
                if (isCompleted) {
                  dutyBreakdown[dutyType]!['completed'] =
                      dutyBreakdown[dutyType]!['completed']! + 1;
                }
              }
            }
          }
        }

        // Completion rate excludes upcoming — completed, missed, and pendingToday are "due so far"
        final dueSoFar = completedCount + missedCount + pendingTodayCount;
        final completionRate =
            dueSoFar == 0 ? 0.0 : (completedCount / dueSoFar * 100);

        performance.add({
          'teacherId':    teacher.id,
          'teacherName':  teacher.name,
          'totalAssigned': totalAssigned,
          'completed':    completedCount,
          'inProgress':   inProgressCount,
          'missed':       missedCount,
          'pendingToday': pendingTodayCount,
          'upcoming':     upcomingCount,
          'completionRate': completionRate,
          'grade': completionRate >= 90
              ? 'Excellent'
              : completionRate >= 70
                  ? 'Good'
                  : completionRate >= 50
                      ? 'Fair'
                      : 'Needs Attention',
          'gradeColor': completionRate >= 90
              ? 0xFF388E3C
              : completionRate >= 70
                  ? 0xFF1976D2
                  : completionRate >= 50
                      ? 0xFFF57C00
                      : 0xFFD32F2F,
          'dutyBreakdown': dutyBreakdown,
        });
      }

      // Default sort: completion rate descending
      performance.sort((a, b) => (b['completionRate'] as double)
          .compareTo(a['completionRate'] as double));

      // Prepend metadata entry so the view layer knows the tracking start date
      // without needing a second async call.
      performance.insert(0, {
        'meta': true,
        'trackingStartDate': trackingStartDate,
      });

      return performance;
    } catch (e) {
      debugPrint('Monthly performance error: $e');
      return [];
    }
  }

  /// Sends a duty reminder notification to a teacher.
  Future<bool> sendDutyReminder({
    required String teacherId,
    required String principalId,
    required String dutyType,
    required String zone,
    required String scheduleId,
  }) async {
    try {
      final displayName = DutyConstants.displayName(dutyType);
      await _notificationService.sendDutyReminderNotification(
        receiverId: teacherId,
        senderId: principalId,
        title: 'Duty Reminder',
        message: 'Please complete your $displayName at $zone.',
        dutyType: displayName,
        zone: zone,
        scheduleId: scheduleId,
        type: 'duty_reminder',
      );
      return true;
    } catch (e) {
      debugPrint('Error sending duty reminder: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _checklistSubscription?.cancel();
    super.dispose();
  }
}
