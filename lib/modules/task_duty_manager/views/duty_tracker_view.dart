import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../constants/duty_constants.dart';
import '../models/checklist_log_model.dart';
import '../models/duty_schedule_model.dart';
import '../providers/duty_provider.dart';

class DutyTrackerView extends StatefulWidget {
  const DutyTrackerView({super.key});

  @override
  State<DutyTrackerView> createState() => _DutyTrackerViewState();
}

class _DutyTrackerViewState extends State<DutyTrackerView> {
  Map<String, String> _teacherNamesMap = {};
  bool _isLoadingTeachers = true;

  @override
  void initState() {
    super.initState();
    _loadTeacherNames();
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
      debugPrint('Error loading teacher names: $e');
      setState(() {
        _isLoadingTeachers = false;
      });
    }
  }

  String _formatLongDate(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _weekdayName(int weekday) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return days[weekday - 1];
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
                  'Only principals and admin users can access the duty completion tracker.',
                  style: GoogleFonts.inter(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final provider = Provider.of<DutyProvider>(context, listen: false);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final now = DateTime.now();
    final weekStart = DutyScheduleModel.weekStartFor(now);
    final dayName = _weekdayName(now.weekday);
    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          'Duty Completion Tracker',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoadingTeachers
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  children: [
                    // Date header card
                    Container(
                      color: Colors.white,
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tracking Roster & Completions',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatLongDate(now),
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Real-time view of teacher checklist completions today.',
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),

                    // Main completions list
                    Expanded(
                      child: isWeekend
                          ? _buildWeekendPlaceholder()
                          : StreamBuilder<List<DutyScheduleModel>>(
                              stream: provider.streamPublishedSchedulesForWeek(weekStart),
                              builder: (context, scheduleSnapshot) {
                                if (scheduleSnapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                final schedules = scheduleSnapshot.data ?? [];

                                return StreamBuilder<List<ChecklistLogModel>>(
                                  stream: provider.streamLogsForDate(now),
                                  builder: (context, logsSnapshot) {
                                    if (logsSnapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    final logs = logsSnapshot.data ?? [];

                                    return _buildTrackerList(schedules, logs, dayName);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWeekendPlaceholder() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wb_sunny_outlined, size: 80, color: Colors.orange.shade300),
            const SizedBox(height: 16),
            Text(
              'Weekend',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937)),
            ),
            const SizedBox(height: 8),
            Text(
              'No duties are scheduled on weekends.',
              style: GoogleFonts.inter(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackerList(
    List<DutyScheduleModel> schedules,
    List<ChecklistLogModel> logs,
    String dayName,
  ) {
    if (schedules.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No Published Schedules',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'There are no published schedules for this week yet.',
                style: GoogleFonts.inter(color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: DutyConstants.allDutyTypes.map((dutyType) {
        final schedule = schedules.firstWhere(
          (s) => s.dutyType == dutyType,
          orElse: () => DutyScheduleModel(
            id: '',
            dutyType: dutyType,
            weekStart: DateTime.now(),
            weekEnd: DateTime.now(),
            generatedAt: DateTime.now(),
            generatedBy: '',
            status: 'Draft',
            assignments: {},
          ),
        );

        final isPublished = schedule.id.isNotEmpty;

        return _buildDutyTypeGroupCard(dutyType, schedule, isPublished, logs, dayName);
      }).toList(),
    );
  }

  Widget _buildDutyTypeGroupCard(
    String dutyType,
    DutyScheduleModel schedule,
    bool isPublished,
    List<ChecklistLogModel> logs,
    String dayName,
  ) {
    final themeColor = Color(DutyConstants.dutyColors[dutyType] ?? 0xFF1E5480);
    final String emoji = DutyConstants.icon(dutyType);
    final zones = DutyConstants.zonesFor(dutyType);

    final dayKey = dutyType == DutyConstants.assembly ? 'Monday' : dayName;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header banner
          Container(
            color: themeColor.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DutyConstants.displayName(dutyType),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: themeColor,
                    ),
                  ),
                ),
                if (!isPublished)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Unpublished',
                      style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),

          if (!isPublished)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Roster draft exists but is not published.',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: zones.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final zone = zones[index];
                final uids = schedule.assignments[dayKey]?[zone] ?? [];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Zone Name
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              zone,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: const Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DutyConstants.timeSlot(dutyType),
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Assigned Teachers & Statuses
                      Expanded(
                        flex: 3,
                        child: uids.isEmpty
                            ? Text(
                                'Unassigned',
                                style: GoogleFonts.inter(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13,
                                  color: Colors.grey.shade400,
                                ),
                              )
                            : Column(
                                children: uids.map((uid) {
                                  // For Assembly Sub Theme, display text directly
                                  final isSubTheme = zone == DutyConstants.assemblySubThemeKey;
                                  final String name = isSubTheme ? uid : (_teacherNamesMap[uid] ?? uid);

                                  if (isSubTheme) {
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        name,
                                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1F2937), fontWeight: FontWeight.w600),
                                      ),
                                    );
                                  }

                                  // Find checklist log for today
                                  final log = logs.firstWhere(
                                    (l) => l.teacherId == uid && l.zone == zone && l.dutyType == dutyType,
                                    orElse: () => ChecklistLogModel(
                                      id: '',
                                      scheduleId: schedule.id,
                                      teacherId: uid,
                                      dutyType: dutyType,
                                      zone: zone,
                                      assignedDate: DateTime.now(),
                                      items: {},
                                      status: 'Pending',
                                    ),
                                  );

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF1F2937),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildStatusChip(log.status),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;

    switch (status) {
      case 'Completed':
        bg = Colors.green.withValues(alpha: 0.1);
        fg = Colors.green.shade700;
        break;
      case 'InProgress':
      case 'in_progress':
        bg = Colors.orange.withValues(alpha: 0.1);
        fg = Colors.orange.shade700;
        break;
      case 'Pending':
      default:
        bg = Colors.red.withValues(alpha: 0.1);
        fg = Colors.red.shade700;
    }

    final displayStatus = status == 'InProgress' ? 'In Progress' : status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        displayStatus,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
