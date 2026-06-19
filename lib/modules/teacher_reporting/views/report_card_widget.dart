import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
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
    final trimmed = urlString.trim();
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
        const SnackBar(content: Text('Invalid or empty evidence link.')),
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
                child: Text('Evidence Image', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
                child: Text('Evidence Document', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
                        ..download = 'evidence' + (isPdf ? '.pdf' : '');
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
    final bool isImage = url.toLowerCase().contains('.png') ||
        url.toLowerCase().contains('.jpg') ||
        url.toLowerCase().contains('.jpeg') ||
        url.toLowerCase().contains('.webp') ||
        url.toLowerCase().contains('image') ||
        url.contains('report_evidence_');

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
                'Evidence File / Link',
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
          if (isImage) ...[
            const SizedBox(height: 10),
            DocumentEvidencePreviewWidget(url: url),
          ],
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

class DocumentEvidencePreviewWidget extends StatefulWidget {
  final String url;
  const DocumentEvidencePreviewWidget({super.key, required this.url});

  @override
  State<DocumentEvidencePreviewWidget> createState() => _DocumentEvidencePreviewWidgetState();
}

class _DocumentEvidencePreviewWidgetState extends State<DocumentEvidencePreviewWidget> {
  String? _resolvedUrl;
  bool _loading = true;
  bool _isImage = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final trimmed = widget.url.trim();
    if (trimmed.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    String actual = trimmed;
    if (trimmed.startsWith('user_documents/') || trimmed.startsWith('/user_documents/')) {
      final docPath = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
      try {
        final doc = await FirebaseFirestore.instance.doc(docPath).get();
        final fetched = doc.data()?['url'] as String?;
        if (fetched != null) {
          actual = fetched;
        }
      } catch (_) {}
    }

    final isImg = actual.startsWith('data:image/') ||
        actual.toLowerCase().contains('.png') ||
        actual.toLowerCase().contains('.jpg') ||
        actual.toLowerCase().contains('.jpeg') ||
        actual.toLowerCase().contains('.webp') ||
        actual.toLowerCase().contains('.gif') ||
        actual.toLowerCase().contains('image');

    if (mounted) {
      setState(() {
        _resolvedUrl = actual;
        _isImage = isImg;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (!_isImage || _resolvedUrl == null) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          _resolvedUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 50)),
        ),
      ),
    );
  }
}
