import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../constants/duty_constants.dart';
import '../providers/duty_provider.dart';
import 'duty_assignment_picker.dart';

class DutyRosterView extends StatefulWidget {
  const DutyRosterView({super.key});

  @override
  State<DutyRosterView> createState() => _DutyRosterViewState();
}

class _DutyRosterViewState extends State<DutyRosterView> {
  Map<String, String> _teacherNamesMap = {};
  bool _isLoadingTeachers = true;

  @override
  void initState() {
    super.initState();
    // Schedule loader after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<DutyProvider>(context, listen: false);
      provider.loadWeekSchedule();
      provider.setSelectedDay(provider.selectedDay);
      _loadTeacherNames();
    });
  }

  Future<void> _loadTeacherNames() async {
    try {
      final provider = Provider.of<DutyProvider>(context, listen: false);
      final teachers = await provider.getAllTeachers();
      final Map<String, String> nameMap = {};
      for (final t in teachers) {
        nameMap[t.id] = t.name;
      }
      setState(() {
        _teacherNamesMap = nameMap;
        _isLoadingTeachers = false;
      });
    } catch (e) {
      debugPrint('Error loading teacher names mapping: $e');
      setState(() {
        _isLoadingTeachers = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatWeekRange(DateTime monday) {
    final friday = monday.add(const Duration(days: 4));
    return '${_formatDate(monday)} – ${_formatDate(friday)}';
  }

  void _openAssignmentPicker({
    required String day,
    required String zone,
    required String dutyType,
    required DateTime weekStart,
    required List<String> currentAssignments,
  }) {
    // Set provider's selectedDutyType to match the card's dutyType
    // so that DutyAssignmentPicker performs saves against the correct schedule.
    final provider = Provider.of<DutyProvider>(context, listen: false);
    provider.selectedDutyType = dutyType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DutyAssignmentPicker(
        day: day,
        zone: zone,
        dutyType: dutyType,
        weekStart: weekStart,
        currentAssignments: currentAssignments,
      ),
    );
  }

  void _confirmAndGenerateForDay(BuildContext context, DutyProvider provider, DateTime weekStart, String dayName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Auto-Generate for $dayName',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Auto-generate assignments for $dayName only? Existing draft assignments for this day will be replaced.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _runGenerationForDay(provider, weekStart, dayName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Confirm', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _runGenerationForDay(DutyProvider provider, DateTime weekStart, String dayName) async {
    await provider.generateForDay(weekStart, dayName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.unassignedSlots.isEmpty
                ? 'Roster auto-generated for $dayName successfully!'
                : 'Roster generated with some unassigned slots.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: provider.unassignedSlots.isEmpty ? Colors.green.shade700 : Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _publishAllWeeklySchedules(DutyProvider provider) async {
    final success = await provider.publishAllSchedules();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'All weekly schedules published successfully!' : 'Failed to publish weekly schedules.',
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUserModel;

    final isAuthorized = user != null &&
        (user.role.toLowerCase() == 'principal' || user.role.toLowerCase() == 'admin');

    if (!isAuthorized) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: AppBar(
          title: Text(
            'Access Denied',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_person_outlined, size: 80, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'Access Restricted',
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only principals and admin users can manage the weekly duty roster.',
                  style: GoogleFonts.inter(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final provider = Provider.of<DutyProvider>(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentWeek = provider.currentWeekStart;

    // Date computation for selected day
    int dayOffset = 0;
    switch (provider.selectedDay) {
      case 'Monday': dayOffset = 0; break;
      case 'Tuesday': dayOffset = 1; break;
      case 'Wednesday': dayOffset = 2; break;
      case 'Thursday': dayOffset = 3; break;
      case 'Friday': dayOffset = 4; break;
    }
    final selectedDate = currentWeek.add(Duration(days: dayOffset));
    final fullDateString = '${provider.selectedDay}, ${_formatDate(selectedDate)}';

    // Statistics computation
    int totalSlots = 0;
    int assignedSlots = 0;
    for (final type in DutyConstants.allDutyTypes) {
      if (type == DutyConstants.assembly && provider.selectedDay != 'Monday') {
        continue;
      }
      final zones = DutyConstants.zonesFor(type);
      for (final zone in zones) {
        if (type == DutyConstants.assembly && zone == DutyConstants.assemblySubThemeKey) {
          continue;
        }
        totalSlots++;
        final sched = provider.allSchedules[type];
        final assigned = sched?.assignments[provider.selectedDay]?[zone] ?? [];
        if (assigned.isNotEmpty && assigned.first != 'UNASSIGNED') {
          assignedSlots++;
        }
      }
    }

    // Dynamic unassigned list for selected day
    final List<String> unassignedForToday = [];
    for (final type in DutyConstants.allDutyTypes) {
      if (type == DutyConstants.assembly && provider.selectedDay != 'Monday') {
        continue;
      }
      final sched = provider.allSchedules[type];
      final zones = DutyConstants.zonesFor(type);
      for (final zone in zones) {
        if (type == DutyConstants.assembly && zone == DutyConstants.assemblySubThemeKey) {
          continue;
        }
        final assigned = sched?.assignments[provider.selectedDay]?[zone] ?? [];
        if (assigned.isEmpty || assigned.first == 'UNASSIGNED') {
          unassignedForToday.add('${DutyConstants.displayName(type)}: $zone');
        }
      }
    }

    // Duty display order sorted chronologically (morning → evening).
    // Assembly is Monday-only and always shown last when present.
    const Map<String, int> dutyTimeOrder = {
      'Arrival': 0,       // 7:30 – 8:00 AM
      'Dismissal': 1,     // 12:00 – 12:30 PM / 5:00 – 5:15 PM
      'HalfFullDay': 2,   // 12:00 – 2:30 PM
      'Cleaning': 3,      // 4:30 – 5:00 PM
      'Assembly': 4,      // Every Monday — always last
    };

    final activeTypes = DutyConstants.allDutyTypes
        .where((type) {
          if (type == DutyConstants.assembly) {
            return provider.selectedDay == 'Monday';
          }
          return true;
        })
        .toList()
      ..sort((a, b) => (dutyTimeOrder[a] ?? 99).compareTo(dutyTimeOrder[b] ?? 99));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          'Manage Weekly Roster',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: provider.isLoading || _isLoadingTeachers
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Week navigation bar
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 0.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: provider.isViewingPastWeek ? null : provider.previousWeek,
                            icon: Icon(
                              Icons.chevron_left,
                              color: provider.isViewingPastWeek
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: provider.isViewingPastWeek
                                  ? Colors.grey.shade50
                                  : Colors.grey.shade100,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'Scheduled Week',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatWeekRange(currentWeek),
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1F2937),
                                  ),
                                ),
                                if (provider.isReadOnly)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '🔒 View Only',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: provider.isViewingFutureWeek ? null : provider.nextWeek,
                            icon: Icon(
                              Icons.chevron_right,
                              color: provider.isViewingFutureWeek
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: provider.isViewingFutureWeek
                                  ? Colors.grey.shade50
                                  : Colors.grey.shade100,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 1b. Weekend info banner
                  if (DateTime.now().weekday == DateTime.saturday ||
                      DateTime.now().weekday == DateTime.sunday)
                    Card(
                      color: Colors.blue.shade50,
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.blue.shade200, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: Colors.blue.shade700, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "📅 It's the weekend — showing next week's schedule for planning",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 2. Horizontal Day Selector Strip
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: DutyConstants.weekdays.map((dayName) {
                          final isSelected = provider.selectedDay == dayName;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(
                                dayName,
                                style: GoogleFonts.inter(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.white : Colors.grey.shade700,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  provider.setSelectedDay(dayName);
                                }
                              },
                              selectedColor: primaryColor,
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected ? Colors.transparent : Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                              showCheckmark: false,
                              elevation: isSelected ? 2 : 0,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // 3. Day Header card
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 0.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                fullDateString,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$assignedSlots / $totalSlots Assigned',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (provider.onLeaveTodayTeachers.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200, width: 1),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade800, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Teachers on approved leave today: ${provider.onLeaveTodayTeachers.join(", ")}',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.red.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 4. Per-Day Auto-Generate Button — hidden in read-only mode
                  if (!provider.isReadOnly)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: provider.isGeneratingDay
                              ? null
                              : () => _confirmAndGenerateForDay(context, provider, currentWeek, provider.selectedDay),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: primaryColor.withValues(alpha: 0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: provider.isGeneratingDay
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                          label: Text(
                            '✨ Auto-Generate for ${provider.selectedDay}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 5. Weekly Draft/Publish Status banner (or read-only banner)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: provider.isReadOnly || provider.isViewingFutureWeek
                        // ── Read-only / past week banner ──
                        ? Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade300, width: 1),
                            ),
                            color: Colors.grey.shade100,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(Icons.lock_outline, color: Colors.grey.shade500, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '📁 This is a past week — view only mode',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        // ── Normal Draft / Published banner ──
                        : Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: provider.weeklyStatus == 'Published'
                                    ? Colors.green.shade200
                                    : Colors.amber.shade300,
                                width: 1,
                              ),
                            ),
                            color: provider.weeklyStatus == 'Published'
                                ? Colors.green.shade50
                                : Colors.amber.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    provider.weeklyStatus == 'Published'
                                        ? Icons.check_circle
                                        : Icons.warning_amber_rounded,
                                    color: provider.weeklyStatus == 'Published'
                                        ? Colors.green.shade700
                                        : Colors.amber.shade800,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      provider.weeklyStatus == 'Published'
                                          ? 'Weekly Roster is Published — teachers have been notified'
                                          : 'Weekly Roster is in Draft mode — review and publish when ready',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: provider.weeklyStatus == 'Published'
                                            ? Colors.green.shade900
                                            : Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                  if (provider.weeklyStatus == 'Draft') ...[
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _publishAllWeeklySchedules(provider),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        'Publish Week',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                  ),

                  // 6. Unassigned warnings (ExpansionTile)
                  if (unassignedForToday.isNotEmpty)
                    Card(
                      color: Colors.red.shade50,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.shade200, width: 1),
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          iconColor: Colors.red.shade900,
                          collapsedIconColor: Colors.red.shade900,
                          title: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red.shade800, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '⚠️ ${unassignedForToday.length} slots are unassigned today. Tap to view.',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.red.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Please assign them manually:',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...unassignedForToday.map((slot) => Padding(
                                        padding: const EdgeInsets.only(bottom: 4.0),
                                        child: Row(
                                          children: [
                                            Icon(Icons.arrow_right_alt, size: 14, color: Colors.red.shade700),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                slot,
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.red.shade900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 7. Duty Cards for Selected Day
                  ...activeTypes.map((type) {
                    final accentColor = Color(DutyConstants.dutyColors[type] ?? 0xFF1565C0);
                    final zones = DutyConstants.zonesFor(type);
                    final sched = provider.allSchedules[type];

                    return Card(
                      key: ValueKey('${provider.selectedDay}_${type}_${provider.currentWeekStart}'),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.white,
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        leading: CircleAvatar(
                          backgroundColor: accentColor.withValues(alpha: 0.1),
                          child: Text(
                            DutyConstants.icon(type),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        title: Text(
                          DutyConstants.displayName(type),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        subtitle: Text(
                          DutyConstants.timeSlot(type),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        children: [
                          const Divider(height: 1),
                          ...zones.map((zone) {
                            final assigned = sched?.assignments[provider.selectedDay]?[zone] ?? [];
                            final isThemeKey = zone == DutyConstants.assemblySubThemeKey;
                            final isUnassigned = assigned.isEmpty || assigned.first == 'UNASSIGNED';

                            return Column(
                              children: [
                                InkWell(
                                  onTap: provider.isReadOnly
                                      ? null
                                      : () => _openAssignmentPicker(
                                          day: provider.selectedDay,
                                          zone: zone,
                                          dutyType: type,
                                          weekStart: currentWeek,
                                          currentAssignments: isUnassigned ? [] : assigned,
                                        ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            zone,
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: const Color(0xFF374151),
                                            ),
                                          ),
                                        ),
                                        if (isThemeKey)
                                          Expanded(
                                            flex: 2,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    assigned.isNotEmpty ? assigned.first : 'No theme set yet',
                                                    style: GoogleFonts.inter(
                                                      fontWeight: FontWeight.w600,
                                                      color: assigned.isNotEmpty
                                                          ? const Color(0xFF1F2937)
                                                          : Colors.grey.shade500,
                                                      fontStyle: assigned.isNotEmpty
                                                          ? FontStyle.normal
                                                          : FontStyle.italic,
                                                      fontSize: 13,
                                                    ),
                                                    textAlign: TextAlign.end,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(Icons.edit_note, size: 18, color: accentColor),
                                              ],
                                            ),
                                          )
                                        else if (isUnassigned)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: Colors.red.shade200, width: 0.5),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.add, size: 12, color: Colors.red.shade700),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Unassigned',
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red.shade700,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: assigned.map((uid) {
                                              final name = _teacherNamesMap[uid] ?? uid;
                                              final isOnLeave = provider.onLeaveTodayTeacherUids.contains(uid);

                                              if (isOnLeave) {
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.shade50,
                                                    borderRadius: BorderRadius.circular(16),
                                                    border: Border.all(color: Colors.red.shade300, width: 0.5),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red.shade700),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '$name (⚠️ On Leave)',
                                                        style: GoogleFonts.inter(
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.red.shade900,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }

                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(color: Colors.green.shade300, width: 0.5),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.person, size: 12, color: Colors.green.shade700),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      name,
                                                      style: GoogleFonts.inter(
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.green.shade900,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (zone != zones.last) const Divider(height: 1, indent: 16, endIndent: 16),
                              ],
                            );
                          }),
                        ],
                      ),
                    );
                  }),

                  // 8. Tip text at the bottom
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      '💡 Tip: Tap on any zone row to assign teachers. The picker will filter out teachers who are on approved leave for that day.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
