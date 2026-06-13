import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/views/login_view.dart';
import '../../leave_management/views/leave_history_view.dart';
import '../../leave_management/views/admin_leave_approval_view.dart';
import '../../leave_management/views/notification_view.dart';
import '../../manage_teachers/views/manage_teachers_view.dart';
import '../../task_duty_manager/views/duty_home_view.dart';
import '../../teacher_training_tracker/views/training_dashboard_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserModel;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: user?.id ?? '')
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              int unreadCount = 0;
              if (snapshot.hasData && snapshot.data != null) {
                unreadCount = snapshot.data!.docs.length;
              }

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationView(),
                        ),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
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
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginView()),
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    Icons.person,
                    size: 50,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome, ${user?.name ?? "User"}!',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user?.role.toUpperCase() ?? "ROLE",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Placeholder for the Leave Management module
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.event_available,
                        color: Colors.green,
                      ),
                    ),
                    title: Text(
                      'Leave Management',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Apply for leave and track your balance',
                      style: GoogleFonts.inter(color: Colors.grey.shade600),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      if (user?.role.toLowerCase() == 'principal') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminLeaveApprovalView(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LeaveHistoryView(),
                          ),
                        );
                      }
                    },
                  ),
                ),
                // Task & Duty Manager card — visible to ALL roles
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.assignment_turned_in_outlined,
                        color: Colors.teal,
                      ),
                    ),
                    title: Text(
                      'Task & Duty Manager',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      user?.role.toLowerCase() == 'principal'
                          ? 'Manage duty rosters and track completion'
                          : 'View your assigned duties and checklists',
                      style: GoogleFonts.inter(color: Colors.grey.shade600),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DutyHomeView(),
                        ),
                      );
                    },
                  ),
                ),
                // Manage Teachers card — visible to Principal only
                if (user?.role.toLowerCase() == 'principal') ...[
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.manage_accounts,
                          color: Colors.indigo,
                        ),
                      ),
                      title: Text(
                        'Manage Teachers',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'View and manage all registered teachers',
                        style: GoogleFonts.inter(color: Colors.grey.shade600),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManageTeachersView(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                // Teacher Training Tracker card — visible to ALL roles
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.school, color: Colors.green),
                    ),
                    title: Text(
                      'Teacher Training Tracker',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'View and manage teacher training activities',
                      style: GoogleFonts.inter(color: Colors.grey.shade600),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TrainingDashboardView(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
