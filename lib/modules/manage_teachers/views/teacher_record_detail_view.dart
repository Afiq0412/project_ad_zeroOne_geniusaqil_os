import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/providers/auth_provider.dart';
import '../../leave_management/services/notification_service.dart';
import '../models/teacher_manage_model.dart';
import '../providers/manage_teachers_provider.dart';
import 'teacher_record_form_view.dart';

/// Read-only profile view for a single teacher record (Module 1).
class TeacherRecordDetailView extends StatelessWidget {
  final String teacherId;
  final bool canEdit;

  const TeacherRecordDetailView({
    super.key,
    required this.teacherId,
    this.canEdit = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ManageTeachersProvider>();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isPrincipal = authProvider.currentUserModel?.role.toLowerCase() == 'principal';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          'Teacher Profile',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: canEdit
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  tooltip: 'Edit',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TeacherRecordFormView(teacherId: teacherId),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: StreamBuilder<TeacherManageModel?>(
        stream: provider.streamTeacher(teacherId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final teacher = snapshot.data;
          if (teacher == null) {
            return Center(
              child: Text('Record not found.',
                  style: GoogleFonts.inter(color: Colors.grey.shade600)),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _profileHeader(context, teacher),
                    const SizedBox(height: 24),
                    _infoSection(context, teacher),
                    const SizedBox(height: 24),
                    _emergencySection(context, teacher),
                    const SizedBox(height: 24),
                    _documentsSection(context, teacher, isPrincipal),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _profileHeader(BuildContext context, TeacherManageModel t) {
    final nameParts =
        t.name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    final initials = nameParts.length >= 2
        ? '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase()
        : t.name.isNotEmpty
            ? t.name[0].toUpperCase()
            : '?';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              child: Text(
                initials,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.name.isNotEmpty ? t.name : '—',
                    style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937)),
                  ),
                  const SizedBox(height: 4),
                  Text(t.email,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _badge(t.role, Colors.indigo),
                      const SizedBox(width: 8),
                      if (t.isComplete)
                        _badge('Complete', Colors.green)
                      else
                        _badge('Incomplete', Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color.shade700),
      ),
    );
  }

  Widget _infoSection(BuildContext context, TeacherManageModel t) {
    final dob = t.dateOfBirth == null
        ? '—'
        : DateFormat('d MMM yyyy').format(t.dateOfBirth!);

    return _card(
      context,
      title: 'Personal Information',
      icon: Icons.person_outline,
      children: [
        _row('Full Name', t.name),
        _row('IC Number', t.icNumber),
        _row('Gender', t.gender),
        _row('Date of Birth', dob),
        _row('Marital Status', t.maritalStatus),
        _row('Phone Number', t.phoneNumber),
        _row('Email', t.email),
        _row('Address', t.address),
      ],
    );
  }

  Widget _emergencySection(BuildContext context, TeacherManageModel t) {
    return _card(
      context,
      title: 'Emergency Contact',
      icon: Icons.contact_emergency_outlined,
      children: [
        _row('Contact Person', t.emergencyContactName),
        _row('Contact Number', t.emergencyContactPhone),
      ],
    );
  }

  Widget _documentsSection(BuildContext context, TeacherManageModel t, bool isPrincipal) {
    final submittedSlots = TeacherManageModel.documentSlots
        .where((s) => t.documents[s] == true)
        .toList();
    final missingSlots = TeacherManageModel.documentSlots
        .where((s) => t.documents[s] != true)
        .toList();
    final submittedCount = submittedSlots.length;
    final totalCount = TeacherManageModel.documentSlots.length;

    final isMissingAny = missingSlots.isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist_outlined,
                    color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Documents Checklist ($submittedCount / $totalCount)',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                ),
                if (isPrincipal && isMissingAny)
                  FilledButton.icon(
                    onPressed: () async {
                      final missingLabels = missingSlots
                          .map((s) => TeacherManageModel.documentLabels[s] ?? s)
                          .join(', ');
                      
                      final notificationService = NotificationService();
                      await notificationService.sendNotification(
                        userId: t.id,
                        title: 'Document Checklist Reminder',
                        message: 'Principal has requested you to upload the following missing documents in your Profile checklist: $missingLabels.',
                        type: 'reminder',
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Reminder notification sent to ${t.name}!'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.send, size: 14, color: Colors.white),
                    label: const Text('Send Reminder', style: TextStyle(color: Colors.white)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            ...TeacherManageModel.documentSlots.map((slot) {
              final label = TeacherManageModel.documentLabels[slot] ?? slot;
              final done = t.documents[slot] == true;
              final url = t.documentUrls[slot] ?? '';
              return _docRow(context, label, done, url);
            }),
          ],
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937))),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              (value == null || value.trim().isEmpty) ? '—' : value,
              style: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xFF1F2937)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _viewDocument(BuildContext context, String url, String label) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;

    String actualUrl = trimmed;

    if (trimmed.startsWith('user_documents/') || trimmed.startsWith('/user_documents/')) {
      final String docPath = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
      // Show loading indicator dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final doc = await FirebaseFirestore.instance.doc(docPath).get();
        if (context.mounted) Navigator.pop(context); // Close loading indicator
        
        final fetched = doc.data()?['url'] as String?;
        if (fetched == null || fetched.isEmpty) {
          throw Exception('Document content is empty.');
        }
        actualUrl = fetched.trim();
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading indicator in case of error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading document: $e')),
          );
        }
        return;
      }
    }

    if (!context.mounted) return;

    if (!actualUrl.startsWith('data:') && !actualUrl.startsWith('http://') && !actualUrl.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid or empty document content.')),
      );
      return;
    }

    final isImage = actualUrl.startsWith('data:image/') ||
        actualUrl.toLowerCase().contains('.png') ||
        actualUrl.toLowerCase().contains('.jpg') ||
        actualUrl.toLowerCase().contains('.jpeg') ||
        actualUrl.toLowerCase().contains('.webp') ||
        actualUrl.toLowerCase().contains('.gif');

    final isPdf = actualUrl.startsWith('data:application/pdf') ||
        actualUrl.toLowerCase().contains('.pdf');

    if (isImage) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxHeight: 500, maxWidth: 600),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                actualUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Text('Failed to load image'));
                },
              ),
            ),
          ),
        ),
      );
    } else {
      // PDF or other documents
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxHeight: 400, maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPdf ? Icons.picture_as_pdf : Icons.description_outlined,
                  size: 64,
                  color: isPdf ? Colors.red : Colors.blue,
                ),
                const SizedBox(height: 16),
                Text(
                  isPdf ? 'This document is a PDF file.' : 'This document is a Word/other file.',
                  style: GoogleFonts.inter(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (actualUrl.startsWith('data:')) {
                      final anchor = html.AnchorElement(href: actualUrl)
                        ..target = '_blank'
                        ..download = label.replaceAll(' ', '_') + (isPdf ? '.pdf' : '');
                      anchor.click();
                    } else {
                      final urlLaunch = Uri.parse(actualUrl);
                      if (!await launchUrl(urlLaunch, mode: LaunchMode.externalApplication)) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not download or open document.')),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: Text(
                    isPdf ? 'Download PDF' : 'Download Document',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _docRow(BuildContext context, String label, bool submitted, String url) {
    final hasUrl = url.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            submitted ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: submitted ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF1F2937))),
          ),
          if (hasUrl) ...[
            OutlinedButton.icon(
              onPressed: () => _viewDocument(context, url, label),
              icon: const Icon(Icons.open_in_new, size: 12),
              label: const Text('View'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            submitted ? 'Submitted' : 'Pending',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: submitted ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
