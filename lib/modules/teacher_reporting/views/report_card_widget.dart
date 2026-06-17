import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/report_model.dart';
import '../providers/report_provider.dart';

class ReportCard extends StatelessWidget {
  final ReportModel report;
  final bool isAdmin;

  const ReportCard({
    super.key,
    required this.report,
    required this.isAdmin,
  });

  Color get _statusColor {
    switch (report.status) {
      case 'Resolved':
        return Colors.green;
      case 'In Review':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  Color get _categoryColor {
    if (report.isSensitive) return Colors.red.shade100;
    if (report.category == 'Other') return Colors.grey.shade200;
    return Colors.blue.shade50;
  }

  Color get _categoryIconColor {
    if (report.isSensitive) return Colors.red.shade700;
    if (report.category == 'Other') return Colors.grey.shade700;
    return Colors.blue.shade700;
  }

  IconData get _categoryIcon {
    switch (report.category) {
      case 'Sexual Harassment Report':
        return Icons.report_problem_outlined;
      case 'Bullying Report (Physical/Emotional/Social Media)':
        return Icons.front_hand_outlined;
      case 'Conflict between Staff Report':
        return Icons.groups_2_outlined;
      case 'SOP Violation Report':
        return Icons.gavel_outlined;
      case 'Workload Stress Report':
        return Icons.psychology_alt_outlined;
      case 'Teacher Misconduct Report':
        return Icons.person_off_outlined;
      case 'Facility Maintenance Report':
        return Icons.handyman_outlined;
      case 'Teaching Material Shortage Report':
        return Icons.inventory_2_outlined;
      case 'Safety Hazard Report':
        return Icons.health_and_safety_outlined;
      case 'IT/System Problem Report':
        return Icons.computer_outlined;
      case 'Other':
        return Icons.more_horiz;
      default:
        return Icons.description_outlined;
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  Future<void> _launchURL(BuildContext context, String urlString) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the evidence link.')),
      );
    }
  }

  Future<void> _copyLink(BuildContext context, String urlString) async {
    await Clipboard.setData(ClipboardData(text: urlString));
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _categoryColor,
          child: Icon(
            _categoryIcon,
            color: _categoryIconColor,
            size: 22,
          ),
        ),
        title: Text(
          report.category,
          style: GoogleFonts.inter(
              fontWeight: FontWeight.bold, fontSize: 15),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatDate(report.createdAt),
          style: GoogleFonts.inter(
              fontSize: 13, color: Colors.grey.shade600),
        ),
        trailing: Chip(
          label: Text(
            report.status,
            style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold),
          ),
          backgroundColor: _statusColor,
          padding: EdgeInsets.zero,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),

                // Reporter — only shown for admin
                if (isAdmin) ...[
                  _infoRow(Icons.person_outline, 'Reporter',
                      report.reporterName),
                  const SizedBox(height: 8),
                ],

                // Description
                _infoRow(Icons.description_outlined,
                    'Description', report.description),

                if (report.evidenceUrl != null &&
                    report.evidenceUrl!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _evidenceLink(context, report.evidenceUrl!.trim()),
                ],

                // Admin note
                if (report.adminNote != null &&
                    report.adminNote!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.green.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.admin_panel_settings,
                            size: 16,
                            color: Colors.green.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Admin Note: ${report.adminNote}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.green.shade800,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Resolved date
                if (report.resolvedAt != null) ...[
                  const SizedBox(height: 8),
                  _infoRow(
                      Icons.check_circle_outline,
                      'Resolved on',
                      _formatDate(report.resolvedAt!)),
                ],

                // Admin action buttons
                if (isAdmin) ...[
                  const Divider(),
                  ReportAdminActions(report: report),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _evidenceLink(BuildContext context, String url) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text(
                'Evidence Link',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            url,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
                onPressed: () => _copyLink(context, url),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open'),
                onPressed: () => _launchURL(context, url),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF1F2937)),
          ),
        ),
      ],
    );
  }
}

// ── Admin action buttons ───────────────────────────────────────────────────────

class ReportAdminActions extends StatelessWidget {
  final ReportModel report;
  const ReportAdminActions({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ReportProvider>();
    final noteController =
        TextEditingController(text: report.adminNote ?? '');

    return Row(
      children: [
        if (report.status != 'In Review')
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                await provider.updateStatus(
                  reportId: report.id,
                  status: 'In Review',
                );
              },
              icon: const Icon(Icons.visibility,
                  size: 16, color: Colors.orange),
              label: Text('In Review',
                  style: GoogleFonts.inter(
                      color: Colors.orange, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.orange),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        if (report.status != 'In Review')
          const SizedBox(width: 8),
        if (report.status != 'Resolved')
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showResolveDialog(
                  context, provider, noteController),
              icon: const Icon(Icons.check_circle_outline,
                  size: 16, color: Colors.green),
              label: Text('Resolve',
                  style: GoogleFonts.inter(
                      color: Colors.green, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.green),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
      ],
    );
  }

  void _showResolveDialog(
    BuildContext context,
    ReportProvider provider,
    TextEditingController noteController,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('Resolve Report',
            style:
                GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add a note before resolving (optional).',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Admin note...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await provider.updateStatus(
                reportId: report.id,
                status: 'Resolved',
                adminNote: noteController.text.trim().isEmpty
                    ? null
                    : noteController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green),
            child: Text('Resolve',
                style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
