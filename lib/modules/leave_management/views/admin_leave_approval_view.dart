import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/leave_provider.dart';
import '../models/leave_request_model.dart';
import '../../auth/models/user_model.dart';

class AdminLeaveApprovalView extends StatelessWidget {
  const AdminLeaveApprovalView({super.key});

  @override
  Widget build(BuildContext context) {
    final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text('Leave Management', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: StreamBuilder<List<LeaveRequestModel>>(
            stream: leaveProvider.getPendingLeaves(),
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
                      Icon(Icons.check_circle_outline, size: 80, color: Colors.green.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('All caught up!', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('No pending leave requests.', style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 16)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: leaves.length,
                itemBuilder: (context, index) {
                  final leave = leaves[index];
                  return _buildLeaveCard(context, leave, leaveProvider);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showMedicalCertDialog(BuildContext context, LeaveRequestModel leave) {
    if (leave.medicalCert == null) return;
    
    showDialog(
      context: context,
      builder: (context) {
        final isImage = leave.medicalCert!.startsWith('data:image/');
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Medical Certificate',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxHeight: 400, maxWidth: 500),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isImage
                  ? Image.network(
                      leave.medicalCert!,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Text('Failed to load certificate image'),
                        );
                      },
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.picture_as_pdf, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'This certificate is a PDF document.',
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            final anchor = html.AnchorElement(href: leave.medicalCert)
                              ..target = 'blank'
                              ..download = 'medical_certificate.pdf';
                            anchor.click();
                          },
                          icon: const Icon(Icons.download, color: Colors.white),
                          label: const Text('Download PDF', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuotaContainer(BuildContext context, String leaveType, String detailsText, bool isLowQuota) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Teacher Leave Quota / Remaining Balances:',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$leaveType:',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                detailsText,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isLowQuota ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(BuildContext context, LeaveRequestModel leave, LeaveProvider provider) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final isNarrow = MediaQuery.of(context).size.width < 450;

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
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          leave.userName,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  dateFormat.format(leave.createdAt),
                  style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              leave.leaveType,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.date_range, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${dateFormat.format(leave.startDate)} - ${dateFormat.format(leave.endDate)} (${leave.daysCount} day(s))',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reason:', style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(leave.reason, style: GoogleFonts.inter(fontSize: 14)),
                ],
              ),
            ),
            if (leave.leaveType == 'Medical leave (MC)' && leave.medicalCert != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showMedicalCertDialog(context, leave),
                  icon: const Icon(Icons.file_present, color: Colors.white),
                  label: const Text('View Medical Certificate', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            StreamBuilder<UserModel?>(
              stream: provider.getTeacherStream(leave.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Loading teacher quota...', style: TextStyle(fontStyle: FontStyle.italic)),
                  );
                }
                final teacher = snapshot.data;
                if (teacher == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Teacher profile not found', style: TextStyle(color: Colors.red)),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (leave.leaveType == 'Half day leave')
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('leave_requests')
                            .where('userId', isEqualTo: leave.userId)
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

                          final int remainingHalfDays = 2 - currentMonthHalfDayCount;

                          return _buildQuotaContainer(
                            context,
                            leave.leaveType,
                            '$remainingHalfDays / 2 times remaining',
                            remainingHalfDays < 1,
                          );
                        },
                      )
                    else ...[
                      Builder(builder: (context) {
                        final double remaining = teacher.leaveBalances[leave.leaveType] ?? 0.0;
                        final double total = defaultLeaveLimits[leave.leaveType] ?? 8.0;
                        return _buildQuotaContainer(
                          context,
                          leave.leaveType,
                          '${remaining.toStringAsFixed(1)} / ${total.toStringAsFixed(1)} days remaining',
                          remaining < leave.daysCount,
                        );
                      }),
                    ],
                    const SizedBox(height: 16),
                    isNarrow
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton(
                                onPressed: () => _updateStatus(context, provider, leave.id, 'Rejected'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Reject'),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () => _updateStatus(context, provider, leave.id, 'Approved'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Approve', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _updateStatus(context, provider, leave.id, 'Rejected'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _updateStatus(context, provider, leave.id, 'Approved'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Approve', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await provider.sendReminder(
                            senderName: 'Principal',
                            receiverId: leave.userId,
                            leaveType: leave.leaveType,
                            message: 'Please follow up on your pending request for ${leave.leaveType}.',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Reminder nudge sent to teacher!'),
                                backgroundColor: Theme.of(context).colorScheme.primary,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.notifications_active_outlined, size: 16),
                        label: const Text('Send Reminder Nudge'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          side: BorderSide(color: Theme.of(context).colorScheme.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _updateStatus(BuildContext context, LeaveProvider provider, String leaveId, String status) async {
    final success = await provider.updateStatus(leaveId, status);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Leave request $status!')),
      );
    }
  }
}
