import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
                    _documentsSection(context, teacher),
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

  Widget _documentsSection(BuildContext context, TeacherManageModel t) {
    final submitted = TeacherManageModel.documentSlots
        .where((s) => t.documents[s] == true)
        .length;

    return _card(
      context,
      title: 'Documents Checklist ($submitted / ${TeacherManageModel.documentSlots.length})',
      icon: Icons.checklist_outlined,
      children: TeacherManageModel.documentSlots.map((slot) {
        final label = TeacherManageModel.documentLabels[slot] ?? slot;
        final done = t.documents[slot] == true;
        return _docRow(label, done);
      }).toList(),
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

  Widget _docRow(String label, bool submitted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
