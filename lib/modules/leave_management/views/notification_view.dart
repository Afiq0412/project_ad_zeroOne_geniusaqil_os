import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../task_duty_manager/views/duty_checklist_view.dart';
import '../../task_duty_manager/constants/duty_constants.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationView extends StatelessWidget {
  const NotificationView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel!;
    final notificationService = NotificationService();
    final dateFormat = DateFormat('MMM d, h:mm a');

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () async {
              await notificationService.markAllAsRead(user.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('All notifications marked as read', style: GoogleFonts.inter()),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              }
            },
            child: Text(
              'Mark all read',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: StreamBuilder<List<NotificationModel>>(
            stream: notificationService.getUserNotifications(user.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error loading notifications', style: GoogleFonts.inter()));
              }

              final notifications = snapshot.data ?? [];

              if (notifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet.',
                        style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _buildNotificationCard(
                    context,
                    notification,
                    notificationService,
                    dateFormat,
                    user,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _reverseDisplayName(String name) {
    for (var entry in DutyConstants.dutyDisplayNames.entries) {
      if (entry.value == name) {
        return entry.key;
      }
    }
    return name;
  }

  Widget _buildNotificationCard(
    BuildContext context,
    NotificationModel notification,
    NotificationService service,
    DateFormat dateFormat,
    UserModel user,
  ) {
    Color iconBgColor;
    IconData iconData;

    switch (notification.type.toLowerCase()) {
      case 'approved':
        iconBgColor = Colors.green;
        iconData = Icons.check_circle_outline;
        break;
      case 'rejected':
        iconBgColor = Colors.red;
        iconData = Icons.error_outline;
        break;
      case 'submission':
        iconBgColor = Theme.of(context).colorScheme.primary;
        iconData = Icons.assignment_turned_in_outlined;
        break;
      case 'reminder':
        iconBgColor = Colors.orange;
        iconData = Icons.alarm;
        break;
      case 'duty_reminder':
        iconBgColor = Colors.orange.shade800;
        iconData = Icons.notifications_active;
        break;
      default:
        iconBgColor = Colors.grey;
        iconData = Icons.notifications_none;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: notification.isRead
            ? BorderSide.none
            : BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), width: 1.5),
      ),
      elevation: notification.isRead ? 1 : 3,
      color: notification.isRead ? Colors.white : const Color(0xFFF9FAFB),
      child: InkWell(
        onTap: () {
          if (!notification.isRead) {
            service.markAsRead(notification.id);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: iconBgColor.withOpacity(0.1),
                child: Icon(iconData, color: iconBgColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          notification.title,
                          style: GoogleFonts.outfit(
                            fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold,
                            fontSize: 16,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: notification.isRead ? Colors.grey.shade600 : const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          dateFormat.format(notification.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        if (notification.type == 'duty_reminder') ...[
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sent by Principal',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (notification.type == 'duty_reminder') ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await service.markAsRead(notification.id);
                            if (context.mounted) {
                              final reversedType = _reverseDisplayName(notification.dutyType ?? '');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DutyChecklistView(
                                    dutyType: reversedType,
                                    zone: notification.zone ?? '',
                                    date: notification.createdAt,
                                    teacherId: user.id,
                                    teacherName: user.name,
                                    scheduleId: notification.scheduleId ?? '',
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: Text(
                            'View Duty',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
