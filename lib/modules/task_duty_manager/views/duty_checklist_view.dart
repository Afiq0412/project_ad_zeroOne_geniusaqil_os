import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/duty_constants.dart';
import '../models/checklist_log_model.dart';
import '../providers/duty_provider.dart';

class DutyChecklistView extends StatefulWidget {
  final String dutyType;
  final String zone;
  final DateTime date;
  final String teacherId;
  final String teacherName;
  final String scheduleId;

  const DutyChecklistView({
    super.key,
    required this.dutyType,
    required this.zone,
    required this.date,
    required this.teacherId,
    required this.teacherName,
    required this.scheduleId,
  });

  @override
  State<DutyChecklistView> createState() => _DutyChecklistViewState();
}

class _DutyChecklistViewState extends State<DutyChecklistView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DutyProvider>(context, listen: false).loadChecklistLog(
        teacherId: widget.teacherId,
        teacherName: widget.teacherName,
        zone: widget.zone,
        dutyType: widget.dutyType,
        date: widget.date,
        scheduleId: widget.scheduleId,
      );
    });
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
    final provider = Provider.of<DutyProvider>(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final log = provider.currentChecklistLog;
    final status = log?.status ?? 'Pending';

    final hasDetailedChecklist = DutyConstants.hasChecklist(widget.dutyType, widget.zone);
    final checklistItems = DutyConstants.getChecklistItems(widget.zone);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          'Duty Checklist',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: provider.isLoading && log == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    // Top Status Card
                    Container(
                      color: Colors.white,
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DutyConstants.displayName(widget.dutyType),
                                      style: GoogleFonts.outfit(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1F2937),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.zone,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusBadge(status),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Text(
                                _formatLongDate(widget.date),
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Text(
                                'Assigned to: ${widget.teacherName}',
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          if (hasDetailedChecklist && log != null) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Progress Log',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF374151),
                                  ),
                                ),
                                Text(
                                  log.progressLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: log.progressFraction,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                status == 'Completed' ? Colors.green : primaryColor,
                              ),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Scrollable List of checklist items or Mark as Done button
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          clipBehavior: Clip.antiAlias,
                          elevation: 1,
                          child: hasDetailedChecklist
                              ? _buildChecklistItems(log, checklistItems, provider)
                              : _buildSingleToggle(status, provider, primaryColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildChecklistItems(
    ChecklistLogModel? log,
    List<String> items,
    DutyProvider provider,
  ) {
    if (log == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final isChecked = log.items[item] ?? false;

        return CheckboxListTile(
          value: isChecked,
          title: Text(
            item,
            style: GoogleFonts.inter(
              fontSize: 14,
              decoration: isChecked ? TextDecoration.lineThrough : null,
              color: isChecked ? Colors.grey : const Color(0xFF1F2937),
            ),
          ),
          activeColor: Theme.of(context).colorScheme.primary,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          onChanged: (val) {
            if (val != null) {
              provider.toggleChecklistItem(item, val);
            }
          },
        );
      },
    );
  }

  Widget _buildSingleToggle(
    String status,
    DutyProvider provider,
    Color primaryColor,
  ) {
    final isCompleted = status == 'Completed';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            isCompleted ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
            size: 80,
            color: isCompleted ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          Text(
            isCompleted ? 'Duty is Completed!' : 'Duty is Pending completion',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isCompleted
                ? 'Thank you for completing your scheduled duty today.'
                : 'Please complete your scheduled duty and tap the button below to confirm.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: isCompleted ? null : () => provider.markAsDoneForCurrent(),
            icon: Icon(
              isCompleted ? Icons.done : Icons.check_circle_outline,
              color: Colors.white,
            ),
            label: Text(
              isCompleted ? 'Completed' : 'Mark as Done',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCompleted ? Colors.green : primaryColor,
              disabledBackgroundColor: Colors.green.shade400,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: isCompleted ? 0 : 2,
            ),
          ),
        ],
      ),
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

    final displayStatus = status == 'InProgress' ? 'In Progress' : status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayStatus,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
