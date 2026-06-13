import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../constants/duty_constants.dart';
import '../models/duty_schedule_model.dart';
import '../providers/duty_provider.dart';
import 'duty_roster_view.dart';
import 'my_duty_view.dart';
import 'duty_tracker_view.dart';

class DutyHomeView extends StatefulWidget {
  const DutyHomeView({super.key});

  @override
  State<DutyHomeView> createState() => _DutyHomeViewState();
}

class _DutyHomeViewState extends State<DutyHomeView> {
  int _onLeaveCount = 0;
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUserModel;
    if (user == null) return;

    final provider = Provider.of<DutyProvider>(context, listen: false);
    await provider.loadWeekSchedule();

    if (user.role.toLowerCase() == 'teacher') {
      await provider.loadTodayDuties(user.id);
    }

    // Fetch on-leave count for today (both principal and teacher views)
    await _loadOnLeaveCount();
    if (mounted) setState(() => _statsLoaded = true);
  }

  Future<void> _loadOnLeaveCount() async {
    try {
      final today = DateTime.now();
      final checkDate = DateTime(today.year, today.month, today.day);

      // Try status == 'Approved' first, then leaveStatus == 'approved'
      final snapA = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('status', isEqualTo: 'Approved')
          .get();
      final snapB = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('leaveStatus', isEqualTo: 'approved')
          .get();

      final Map<String, Map<String, dynamic>> allDocs = {};
      for (final doc in snapA.docs) { allDocs[doc.id] = doc.data(); }
      for (final doc in snapB.docs) { allDocs.putIfAbsent(doc.id, () => doc.data()); }

      int count = 0;
      for (final data in allDocs.values) {
        final uid = data['userId'] as String?
            ?? data['teacherId'] as String?
            ?? data['uid'] as String?
            ?? '';
        if (uid.isEmpty) continue;

        DateTime? start;
        DateTime? end;
        if (data['leaveDate'] != null) {
          start = (data['leaveDate'] as Timestamp).toDate();
          end = start;
        } else {
          if (data['startDate'] != null) start = (data['startDate'] as Timestamp).toDate();
          if (data['endDate'] != null) end = (data['endDate'] as Timestamp).toDate();
        }
        if (start == null && end == null) continue;
        start ??= end;
        end ??= start;

        final startDay = DateTime(start!.year, start.month, start.day);
        final endDay = DateTime(end!.year, end.month, end.day);
        if (!checkDate.isBefore(startDay) && !checkDate.isAfter(endDay)) {
          count++;
        }
      }
      _onLeaveCount = count;
    } catch (e) {
      debugPrint('DutyHomeView _loadOnLeaveCount error: $e');
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formatDate(DateTime d) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatShortDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUserModel;
    final isPrincipalOrAdmin = user != null &&
        (user.role.toLowerCase() == 'principal' || user.role.toLowerCase() == 'admin');
    final isTeacher = user != null && user.role.toLowerCase() == 'teacher';
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          'Task & Duty Manager',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // ── Role Badge ──────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPrincipalOrAdmin
                              ? Icons.admin_panel_settings_outlined
                              : Icons.person_outlined,
                          size: 16,
                          color: primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isPrincipalOrAdmin ? 'Principal View' : 'Teacher View',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: primary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ─────────────────────────────────────────────────────
              // PRINCIPAL / ADMIN VIEW
              // ─────────────────────────────────────────────────────
              if (isPrincipalOrAdmin)
                _PrincipalView(
                  primary: primary,
                  greeting: _greeting(),
                  dateString: _formatDate(DateTime.now()),
                  onLeaveCount: _onLeaveCount,
                  statsLoaded: _statsLoaded,
                  formatShortDate: _formatShortDate,
                ),

              // ─────────────────────────────────────────────────────
              // TEACHER VIEW
              // ─────────────────────────────────────────────────────
              if (isTeacher)
                _TeacherView(
                  primary: primary,
                  greeting: _greeting(),
                  dateString: _formatDate(DateTime.now()),
                  userName: user.name,
                  formatShortDate: _formatShortDate,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRINCIPAL SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _PrincipalView extends StatelessWidget {
  final Color primary;
  final String greeting;
  final String dateString;
  final int onLeaveCount;
  final bool statsLoaded;
  final String Function(DateTime) formatShortDate;

  const _PrincipalView({
    required this.primary,
    required this.greeting,
    required this.dateString,
    required this.onLeaveCount,
    required this.statsLoaded,
    required this.formatShortDate,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DutyProvider>(
      builder: (context, provider, _) {
        // ── Compute stats from allSchedules ──
        int totalSlots = 0;
        int assignedSlots = 0;
        int publishedCount = 0;
        final now = DateTime.now();
        final todayName = _weekdayName(now.weekday);

        for (final type in DutyConstants.allDutyTypes) {
          final sched = provider.allSchedules[type];
          if (sched != null && sched.status == 'Published') publishedCount++;

          if (type == DutyConstants.assembly && todayName != 'Monday') continue;
          final zones = DutyConstants.zonesFor(type);
          for (final zone in zones) {
            if (type == DutyConstants.assembly &&
                zone == DutyConstants.assemblySubThemeKey) { continue; }
            totalSlots++;
            final assigned = sched?.assignments[todayName]?[zone] ?? [];
            if (assigned.isNotEmpty && assigned.first != 'UNASSIGNED') assignedSlots++;
          }
        }

        final weekStart = provider.currentWeekStart;
        final weekEnd = weekStart.add(const Duration(days: 4));
        final weekRange =
            'Week: ${formatShortDate(weekStart)} – ${formatShortDate(weekEnd)}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Welcome Header Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, Principal 👋',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateString,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      weekRange,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Mini stat chips row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _StatChip(
                            label: '📋 $assignedSlots/$totalSlots Slots Assigned',
                            primary: primary,
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            label: '🏖️ $onLeaveCount On Leave Today',
                            primary: primary,
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            label:
                                '✅ $publishedCount/${DutyConstants.allDutyTypes.length} Published',
                            primary: primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Next week status row
                    Row(
                      children: [
                        Text(
                          'Next Week:',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FutureBuilder<String>(
                          future: provider.getNextWeekStatus(),
                          builder: (context, snapshot) {
                            final status = snapshot.data ?? 'empty';
                            Color chipColor;
                            Color textColor;
                            String label;
                            if (status == 'published') {
                              chipColor = Colors.green.shade50;
                              textColor = Colors.green.shade700;
                              label = '✅ Ready';
                            } else if (status == 'draft') {
                              chipColor = Colors.blue.shade50;
                              textColor = Colors.blue.shade700;
                              label = '📋 In progress';
                            } else {
                              chipColor = Colors.amber.shade50;
                              textColor = Colors.amber.shade800;
                              label = '⚠️ Not planned yet';
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: chipColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                label,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 2. Manage Weekly Roster card
            _NavCard(
              title: 'Manage Weekly Roster',
              subtitle: 'Assign and auto-generate teacher schedules',
              iconData: Icons.calendar_month,
              iconBgColor: primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DutyRosterView()),
              ),
            ),

            const SizedBox(height: 12),

            // 3. Duty Completion Tracker card
            _NavCard(
              title: 'Duty Completion Tracker',
              subtitle: 'Monitor real-time duty completion progress',
              iconData: Icons.checklist,
              iconBgColor: const Color(0xFF0D9488), // teal-600
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DutyTrackerView()),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _weekdayName(int weekday) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return days[weekday - 1];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEACHER SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _TeacherView extends StatelessWidget {
  final Color primary;
  final String greeting;
  final String dateString;
  final String userName;
  final String Function(DateTime) formatShortDate;

  const _TeacherView({
    required this.primary,
    required this.greeting,
    required this.dateString,
    required this.userName,
    required this.formatShortDate,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DutyProvider>(
      builder: (context, provider, _) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final user = authProvider.currentUserModel;
        final teacherUid = user?.id ?? '';
        final todayDutyCount = provider.todayDuties.length;
        final hasDuties = todayDutyCount > 0;

        // Weekend auto-advance: show next week on Sat/Sun
        final now = DateTime.now();
        final isWeekend = now.weekday == DateTime.saturday ||
            now.weekday == DateTime.sunday;
        final todayWeekStart = DutyScheduleModel.weekStartFor(now);
        final glanceWeekStart = isWeekend
            ? todayWeekStart.add(const Duration(days: 7))
            : todayWeekStart;

        // Week-at-a-glance: check teacher UID in PUBLISHED schedules
        final Map<String, bool> hasDutyOnDay = {};
        for (final day in DutyConstants.weekdays) {
          bool found = false;
          for (final type in DutyConstants.allDutyTypes) {
            final sched = provider.allSchedules[type];
            if (sched == null || sched.status != 'Published') continue;
            // Only check if the sched's weekStart matches the glance week
            if (!sched.weekStart.isAtSameMomentAs(glanceWeekStart) &&
                sched.weekStart != glanceWeekStart) {
              continue;
            }
            final dayData = sched.assignments[day] ?? {};
            for (final zone in dayData.keys) {
              final assigned = dayData[zone] ?? [];
              if (assigned.contains(teacherUid)) {
                found = true;
                break;
              }
            }
            if (found) break;
          }
          hasDutyOnDay[day] = found;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Welcome Header Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, $userName 👋',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateString,
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 14),
                    // Today duty status chip
                    provider.isLoading
                        ? const SizedBox(
                            height: 28,
                            width: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: hasDuties
                                  ? primary.withValues(alpha: 0.1)
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              hasDuties
                                  ? '📋 $todayDutyCount ${todayDutyCount == 1 ? 'duty' : 'duties'} today'
                                  : '✅ No duties today — enjoy!',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: hasDuties
                                    ? primary
                                    : Colors.green.shade700,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 2. My Duties Today nav card
            _NavCard(
              title: 'My Duties Today',
              subtitle: 'View and complete your assigned duties',
              iconData: Icons.assignment,
              iconBgColor: primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyDutyView()),
              ),
            ),

            const SizedBox(height: 24),

            // 3. Week at a Glance
            Text(
              'Your Week at a Glance',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isWeekend
                  ? 'Your assigned duties next week (starting Monday)'
                  : 'Your assigned duties this week',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 12),

            // 5-day strip
            Row(
              children: DutyConstants.weekdays.map((day) {
                final hasDuty = hasDutyOnDay[day] ?? false;
                final abbr = day.substring(0, 3); // Mon, Tue…
                final dayOffset = DutyConstants.weekdays.indexOf(day);
                final dayDate = glanceWeekStart.add(Duration(days: dayOffset));

                return Expanded(
                  child: Card(
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            abbr,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${dayDate.day}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasDuty
                                  ? Colors.green.shade500
                                  : Colors.transparent,
                              border: Border.all(
                                color: hasDuty
                                    ? Colors.green.shade500
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: hasDuty
                                ? const Icon(Icons.check,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hasDuty ? 'Duty' : 'Free',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: hasDuty
                                  ? Colors.green.shade700
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _NavCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData iconData;
  final Color iconBgColor;
  final VoidCallback onTap;

  const _NavCard({
    required this.title,
    required this.subtitle,
    required this.iconData,
    required this.iconBgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 22, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color primary;

  const _StatChip({required this.label, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
      ),
    );
  }
}
