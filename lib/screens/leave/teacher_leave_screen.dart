import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_provider.dart';
import '../../models/leave_model.dart';
import '../../models/user_model.dart';
import 'create_leave_screen.dart';

class TeacherLeaveScreen extends StatelessWidget {
  const TeacherLeaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel!;
    final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);

    const Map<String, double> defaultLeaveLimits = {
      'Annual leave': 8.0,
      'Medical leave (MC)': 14.0,
      'Unpaid leave': 8.0,
      'Maternity leave': 98.0,
      'Marriage leave': 5.0,
      'Compassionate leave': 2.0,
      'Umrah leave': 14.0,
      'Haji leave': 40.0,
      'Birthday leave': 1.0,
      'Half day leave': 2.0,
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text('My Leave Requests', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
          // Live Leave Balances Dashboard
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user.id).snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 110,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (userSnapshot.hasError || !userSnapshot.hasData || userSnapshot.data == null) {
                return const SizedBox.shrink();
              }

              final userData = userSnapshot.data!.data() as Map<String, dynamic>;
              final freshUser = UserModel.fromMap(userData, userSnapshot.data!.id);
              final balances = freshUser.leaveBalances;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('leave_requests')
                    .where('userId', isEqualTo: user.id)
                    .where('leaveType', isEqualTo: 'Half day leave')
                    .snapshots(),
                builder: (context, halfDaySnapshot) {
                  final now = DateTime.now();
                  final startOfMonth = DateTime(now.year, now.month, 1);
                  final endOfMonth = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1));

                  int currentMonthHalfDayCount = 0;
                  if (halfDaySnapshot.hasData && halfDaySnapshot.data != null) {
                    currentMonthHalfDayCount = halfDaySnapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final createdAt = (data['createdAt'] as Timestamp).toDate();
                      final status = data['status'] ?? 'Pending';
                      return createdAt.isAfter(startOfMonth) &&
                          createdAt.isBefore(endOfMonth) &&
                          status != 'Rejected';
                    }).length;
                  }

                  final double remainingHalfDays = (2 - currentMonthHalfDayCount).toDouble();

                  return Container(
                    height: 110,
                    color: Colors.white,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      children: balances.entries.map((entry) {
                        final String categoryName = entry.key;
                        double remainingDays = entry.value;
                        double totalDays = defaultLeaveLimits[categoryName] ?? 8.0;

                        if (categoryName == 'Half day leave') {
                          remainingDays = remainingHalfDays;
                          totalDays = 2.0;
                        }

                        final double fraction = totalDays > 0 ? (remainingDays / totalDays) : 0.0;

                        return Card(
                          margin: const EdgeInsets.only(right: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: CircularProgressIndicator(
                                    value: fraction.clamp(0.0, 1.0),
                                    backgroundColor: Colors.grey.shade200,
                                    color: fraction > 0.5
                                        ? Colors.green
                                        : (fraction > 0.2 ? Colors.orange : Colors.red),
                                    strokeWidth: 4,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      categoryName,
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      categoryName == 'Half day leave'
                                          ? '${remainingDays.toStringAsFixed(0)} / ${totalDays.toStringAsFixed(0)} times left'
                                          : '${remainingDays.toStringAsFixed(1)} / ${totalDays.toStringAsFixed(1)} left',
                                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              );
            },
          ),
          const Divider(height: 1),
          // Leave Requests List
          Expanded(
            child: StreamBuilder<List<LeaveModel>>(
              stream: leaveProvider.getUserLeaves(user.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading requests', style: GoogleFonts.inter()));
                }

                final leaves = snapshot.data ?? [];

                if (leaves.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_note, size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('No leave requests found.', style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: leaves.length,
                  itemBuilder: (context, index) {
                    final leave = leaves[index];
                    return _buildLeaveCard(context, leave, leaveProvider, user);
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateLeaveScreen()),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Request Leave', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLeaveCard(BuildContext context, LeaveModel leave, LeaveProvider leaveProvider, UserModel user) {
    Color statusColor;
    switch (leave.status) {
      case 'Approved':
        statusColor = Colors.green;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    final dateFormat = DateFormat('MMM d, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    leave.status,
                    style: GoogleFonts.inter(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                Text(
                  'Applied: ${dateFormat.format(leave.createdAt)}',
                  style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              leave.leaveType,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.date_range, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${dateFormat.format(leave.startDate)} - ${dateFormat.format(leave.endDate)} (${leave.daysCount} day(s))',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Reason:',
              style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              leave.reason,
              style: GoogleFonts.inter(fontSize: 14),
            ),
            if (leave.status == 'Pending') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final principalsSnapshot = await FirebaseFirestore.instance
                        .collection('users')
                        .where('role', whereIn: ['principal', 'Principal'])
                        .get();

                    for (var doc in principalsSnapshot.docs) {
                      await leaveProvider.sendReminder(
                        senderName: user.name,
                        receiverId: doc.id,
                        leaveType: leave.leaveType,
                        message: 'Reminding you to review my pending ${leave.leaveType} request.',
                      );
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reminder sent to Principal!'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.alarm, size: 16),
                  label: const Text('Remind Principal'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
