import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../constants/duty_constants.dart';
import '../models/checklist_log_model.dart';
import '../providers/duty_provider.dart';
import 'duty_checklist_view.dart';
import '../../leave_management/services/notification_service.dart';
import '../../leave_management/models/notification_model.dart';
import '../../leave_management/views/notification_view.dart';

class MyDutyView extends StatefulWidget {
  const MyDutyView({super.key});

  @override
  State<MyDutyView> createState() => _MyDutyViewState();
}

class _MyDutyViewState extends State<MyDutyView> {
  Map<String, String> _teacherNamesMap = {};
  bool _isLoadingTeachers = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUserModel;
    if (user == null) return;

    final dutyProvider = Provider.of<DutyProvider>(context, listen: false);
    await dutyProvider.loadTodayDuties(user.id);
    await _loadTeacherNames();
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

  String _formatLongDate(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserModel;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User details not found. Please log in.')),
      );
    }

    final provider = Provider.of<DutyProvider>(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          'My Duties Today',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          StreamBuilder<List<NotificationModel>>(
            stream: NotificationService().getUserNotifications(user.id),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data?.where((n) => !n.isRead).length ?? 0;

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationView()),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: provider.isLoading || _isLoadingTeachers
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Header date card
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 1,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily Overview',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatLongDate(DateTime.now()),
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Select an assigned duty below to start or update checklist items.',
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Assigned Duties List
                      if (provider.todayDuties.isEmpty)
                        _buildEmptyState()
                      else ...[
                        Text(
                          'Today\'s Assignments',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...provider.todayDuties.map((duty) => _buildDutyCard(context, duty, user.id, user.name)),
                      ]
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.done_all_rounded,
                  size: 48,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No duties assigned today',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You are not scheduled for any tasks today. Enjoy your day!',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDutyCard(
    BuildContext context,
    Map<String, dynamic> duty,
    String loggedInUserId,
    String loggedInUserName,
  ) {
    final String dutyType = duty['dutyType'];
    final String zone = duty['zone'];
    final String timeSlot = duty['timeSlot'];
    final String scheduleId = duty['scheduleId'];
    final List<String> assignedUids = List<String>.from(duty['assignedTeachers'] ?? []);

    final String emoji = DutyConstants.icon(dutyType);
    final themeColor = Color(DutyConstants.dutyColors[dutyType] ?? 0xFF1E5480);

    // Filter assigned names excluding current teacher if they are not the only one
    final coTeachers = assignedUids
        .where((uid) => uid != loggedInUserId)
        .map((uid) => _teacherNamesMap[uid] ?? uid)
        .toList();

    return StreamBuilder<ChecklistLogModel?>(
      stream: Provider.of<DutyProvider>(context, listen: false).streamChecklistLog(
        teacherId: loggedInUserId,
        scheduleId: scheduleId,
        zone: zone,
      ),
      builder: (context, snapshot) {
        final log = snapshot.data;
        final String status = log?.status ?? 'Pending';
        final double progress = log?.progressFraction ?? 0.0;
        final String progressText = log?.progressLabel ?? 'Pending';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          elevation: 3,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DutyChecklistView(
                    dutyType: dutyType,
                    zone: zone,
                    date: duty['date'],
                    teacherId: loggedInUserId,
                    teacherName: loggedInUserName,
                    scheduleId: scheduleId,
                  ),
                ),
              );
            },
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Emoji container
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Duty Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DutyConstants.displayName(dutyType),
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              zone,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: themeColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 13, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  timeSlot,
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            if (coTeachers.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.people_outline, size: 13, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'With: ${coTeachers.join(', ')}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ]
                          ],
                        ),
                      ),

                      // Status Badge
                      _buildStatusBadge(status),
                    ],
                  ),
                ),

                // Progress indicator at the bottom of the card for Cleaning Duty
                if (DutyConstants.hasChecklist(dutyType, zone)) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Checklist progress',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                        ),
                        Text(
                          progressText,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      status == 'Completed' ? Colors.green : themeColor,
                    ),
                    minHeight: 4,
                  ),
                ] else ...[
                  // Simple divider for non-cleaning cards
                  Container(height: 4, color: status == 'Completed' ? Colors.green : Colors.transparent),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
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

    // Format display status
    final displayStatus = status == 'InProgress' ? 'In Progress' : status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayStatus,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
