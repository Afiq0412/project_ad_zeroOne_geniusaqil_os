import 'package:flutter/foundation.dart';
import '../constants/duty_constants.dart';
import '../models/duty_schedule_model.dart';
import 'duty_schedule_service.dart';
import 'rotation_service.dart';

class AutoAssignService {
  final DutyScheduleService _scheduleService = DutyScheduleService();
  final RotationService _rotationService = RotationService();

  /// Generates auto-assignments for ONE specific day only across all 5 duty types.
  /// Overwrites only the selected day's assignments in the weekly schedule.
  /// Returns a list of unassigned slot descriptions for the selected day.
  Future<List<String>> generateForDay(DateTime weekStart, String dayName) async {
    // Step 1 — Build available teacher pool for that day
    // Fetch all active teachers (role == "Teacher")
    final allTeachers = await _rotationService.getActiveTeachers();

    // Fetch approved leave requests map covering Monday to Friday of the week
    final leavesMap = await _scheduleService.getApprovedLeavesForWeek(weekStart);
    final onLeave = leavesMap[dayName]?.toSet() ?? {};

    // Available teachers pool for the day: active teachers not on approved leave today
    final List<String> availablePool = allTeachers
        .where((t) => !onLeave.contains(t.id))
        .map((t) => t.id)
        .toList();

    // Full diagnostics — check console output to verify leave filtering
    debugPrint('=== generateForDay: $dayName ===');
    debugPrint('All teachers: ${allTeachers.map((t) => "${t.id}:${t.name}").toList()}');
    debugPrint('Leaves map keys: ${leavesMap.keys.toList()}');
    debugPrint('On leave UIDs for $dayName: $onLeave');
    debugPrint('Available pool after filtering: $availablePool');

    // Step 2 — Load rotation history
    final trackerList = await _rotationService.getRotationData();
    // Build a lookup map: { "teacherUID_dutyType_zone": { totalAssignments, lastAssignedDate } }
    final Map<String, Map<String, dynamic>> rotationHistory = {};
    for (final t in trackerList) {
      final key = '${t.teacherId}_${t.dutyType}_${t.zone}';
      rotationHistory[key] = {
        'totalAssignments': t.totalAssignments,
        'lastAssignedDate': t.lastAssignedDate,
      };
    }

    // Step 3 — Assign per duty type per zone for that day
    // Temporary in-memory used-today zone counts for this generation run: { teacherId_zone: count }
    final Map<String, int> tempDayZoneCounts = {};

    // Track assigned duties per teacher today (across all duty types): { teacherId: count }
    final Map<String, int> teacherDutiesToday = {};

    // Track zones assigned to a teacher on this day: { teacherId: Set<zone> }
    final Map<String, Set<String>> teacherZonesToday = {};

    int getDailyDutyCount(String teacherId) {
      return teacherDutiesToday[teacherId] ?? 0;
    }

    // dayAssignments: { dutyType: { zone: teacherUID } }
    final Map<String, Map<String, String>> dayAssignments = {};

    for (final dutyType in DutyConstants.allDutyTypes) {
      dayAssignments[dutyType] = {};

      // Assembly Duty is Monday only
      if (dutyType == DutyConstants.assembly && dayName != 'Monday') {
        continue;
      }

      final zones = DutyConstants.zonesFor(dutyType);
      for (final zone in zones) {
        // Skip Sub Theme (Assembly text field)
        if (dutyType == DutyConstants.assembly && zone == DutyConstants.assemblySubThemeKey) {
          continue;
        }

        // Never assign the same teacher to the same zone on the same day twice.
        final candidates = availablePool.where((uid) {
          final assignedZones = teacherZonesToday[uid] ?? {};
          return !assignedZones.contains(zone);
        }).toList();

        if (candidates.isEmpty) {
          dayAssignments[dutyType]![zone] = 'UNASSIGNED';
          continue;
        }

        // Soft preference tiering:
        // - First: prefer teachers with 0 duties today
        // - Then: allow teachers with 1 duty today
        // - Then: allow teachers with 2 duties today
        // - Else: allow teachers with 3+ duties today
        List<String> tierCandidates = [];
        final zeroDuty = candidates.where((uid) => getDailyDutyCount(uid) == 0).toList();
        final oneDuty = candidates.where((uid) => getDailyDutyCount(uid) == 1).toList();
        final twoDuties = candidates.where((uid) => getDailyDutyCount(uid) == 2).toList();
        final threeOrMore = candidates.where((uid) => getDailyDutyCount(uid) >= 3).toList();

        if (zeroDuty.isNotEmpty) {
          tierCandidates = zeroDuty;
        } else if (oneDuty.isNotEmpty) {
          tierCandidates = oneDuty;
        } else if (twoDuties.isNotEmpty) {
          tierCandidates = twoDuties;
        } else {
          tierCandidates = threeOrMore;
        }

        // Sort tierCandidates by:
        // 1. In-memory tempDayZoneCounts for that zone -> ascending
        // 2. Persistent tracker totalAssignments for dutyType + zone -> ascending
        // 3. lastAssignedDate -> ascending (null = highest priority)
        tierCandidates.sort((a, b) {
          final aTempKey = '${a}_$zone';
          final bTempKey = '${b}_$zone';
          final aTemp = tempDayZoneCounts[aTempKey] ?? 0;
          final bTemp = tempDayZoneCounts[bTempKey] ?? 0;
          if (aTemp != bTemp) {
            return aTemp.compareTo(bTemp);
          }

          final aKey = '${a}_${dutyType}_$zone';
          final bKey = '${b}_${dutyType}_$zone';
          final aHist = rotationHistory[aKey];
          final bHist = rotationHistory[bKey];

          final aCount = aHist?['totalAssignments'] as int? ?? 0;
          final bCount = bHist?['totalAssignments'] as int? ?? 0;
          if (aCount != bCount) {
            return aCount.compareTo(bCount);
          }

          final aDate = aHist?['lastAssignedDate'] as DateTime?;
          final bDate = bHist?['lastAssignedDate'] as DateTime?;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return -1;
          if (bDate == null) return 1;
          return aDate.compareTo(bDate);
        });

        // Pick top teacher
        final chosenTeacherId = tierCandidates.first;

        // Secondary safety check — never assign a teacher who is on approved leave,
        // even if they somehow slipped through the initial pool filter.
        if (onLeave.contains(chosenTeacherId)) {
          debugPrint('[AutoAssign] WARNING: $chosenTeacherId is on leave but was chosen — marking slot as UNASSIGNED.');
          dayAssignments[dutyType]![zone] = 'UNASSIGNED';
          continue;
        }

        // Assign
        dayAssignments[dutyType]![zone] = chosenTeacherId;

        // Increment in-memory counts
        final tempKey = '${chosenTeacherId}_$zone';
        tempDayZoneCounts[tempKey] = (tempDayZoneCounts[tempKey] ?? 0) + 1;
        teacherDutiesToday[chosenTeacherId] = getDailyDutyCount(chosenTeacherId) + 1;
        teacherZonesToday[chosenTeacherId] ??= {};
        teacherZonesToday[chosenTeacherId]!.add(zone);
      }
    }

    // Step 4 — Merge with existing week schedule
    final List<String> unassignedSlots = [];

    for (final dutyType in DutyConstants.allDutyTypes) {
      if (dutyType == DutyConstants.assembly && dayName != 'Monday') {
        continue;
      }

      final existingSchedule = await _scheduleService.getScheduleForWeek(dutyType, weekStart);

      // Prepare updated assignments map preserving all other days untouched
      final Map<String, Map<String, List<String>>> updatedAssignments = {};
      if (existingSchedule != null) {
        for (final dayKey in existingSchedule.assignments.keys) {
          updatedAssignments[dayKey] = {
            for (final zKey in existingSchedule.assignments[dayKey]!.keys)
              zKey: List<String>.from(existingSchedule.assignments[dayKey]![zKey] ?? [])
          };
        }
      }

      // Initialize selected day's assignments map
      updatedAssignments[dayName] = {};

      final dayData = dayAssignments[dutyType] ?? {};
      for (final zone in dayData.keys) {
        final teacherId = dayData[zone]!;
        if (teacherId == 'UNASSIGNED') {
          unassignedSlots.add('${DutyConstants.displayName(dutyType)}: $zone');
        }
        updatedAssignments[dayName]![zone] = [teacherId];
      }

      // Preserve Assembly Sub Theme text
      if (dutyType == DutyConstants.assembly && dayName == 'Monday') {
        String existingSubTheme = '';
        if (existingSchedule != null &&
            existingSchedule.assignments['Monday'] != null &&
            existingSchedule.assignments['Monday']![DutyConstants.assemblySubThemeKey] != null &&
            existingSchedule.assignments['Monday']![DutyConstants.assemblySubThemeKey]!.isNotEmpty) {
          existingSubTheme = existingSchedule.assignments['Monday']![DutyConstants.assemblySubThemeKey]!.first;
        }
        updatedAssignments['Monday']![DutyConstants.assemblySubThemeKey] = [existingSubTheme];
      }

      if (existingSchedule != null) {
        final updated = existingSchedule.copyWith(
          status: 'Draft',
          assignments: updatedAssignments,
        );
        await _scheduleService.saveSchedule(updated);
      } else {
        final newSchedule = DutyScheduleModel(
          id: '',
          dutyType: dutyType,
          weekStart: weekStart,
          weekEnd: DutyScheduleModel.weekEndFor(weekStart),
          generatedAt: DateTime.now(),
          generatedBy: 'Principal',
          status: 'Draft',
          assignments: updatedAssignments,
        );
        await _scheduleService.saveSchedule(newSchedule);
      }
    }

    // Step 5 — Return unassigned slots
    return unassignedSlots;
  }
}
