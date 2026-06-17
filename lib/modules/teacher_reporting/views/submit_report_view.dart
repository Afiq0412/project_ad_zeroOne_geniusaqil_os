import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/report_model.dart';
import '../providers/report_provider.dart';

class SubmitReportView extends StatefulWidget {
  const SubmitReportView({super.key});

  @override
  State<SubmitReportView> createState() => _SubmitReportViewState();
}

class _SubmitReportViewState extends State<SubmitReportView> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  String? _selectedCategory;
  bool _submitting = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      _snack('Please select a report category.');
      return;
    }

    setState(() => _submitting = true);

    final user =
        context.read<AuthProvider>().currentUserModel;
    final provider = context.read<ReportProvider>();

    if (user == null || user.id.isEmpty) {
      if (mounted) setState(() => _submitting = false);
      _snack('Please log in again before submitting a report.');
      return;
    }

    final success = await provider.submitReport(
      reporterId: user.id,
      reporterName: user.name,
      category: _selectedCategory!,
      description: _descController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      _snack('Report submitted successfully.');
      Navigator.pop(context);
    } else {
      _snack(provider.errorMessage ?? 'Failed to submit report.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
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

  bool _isSensitiveCategory(String category) {
    return ReportModel(
      id: '',
      reporterId: '',
      reporterName: '',
      category: category,
      description: '',
      status: '',
      createdAt: DateTime.now(),
    ).isSensitive;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text('Submit Report',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Privacy notice for sensitive reports
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue.shade600, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your report will be reviewed by the principal. '
                            'Sensitive reports are handled with confidentiality.',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text('Report Category',
                      style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937))),
                  const SizedBox(height: 10),

                  // Category grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 76,
                    ),
                    itemCount: ReportModel.categories.length,
                    itemBuilder: (context, index) {
                      final cat = ReportModel.categories[index];
                      final selected = _selectedCategory == cat;
                      final isSensitive = _isSensitiveCategory(cat);
                      final activeColor = isSensitive
                          ? Colors.red.shade700
                          : Theme.of(context).colorScheme.primary;
                      final idleIconColor = isSensitive
                          ? Colors.red.shade600
                          : Colors.grey.shade600;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? activeColor.withValues(alpha: 0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? activeColor
                                  : Colors.grey.shade300,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                _categoryIcon(cat),
                                size: 22,
                                color: selected
                                    ? activeColor
                                    : idleIconColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  cat,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    height: 1.25,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: selected
                                        ? activeColor
                                        : const Color(0xFF1F2937),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Sensitive notice
                  if (_selectedCategory != null &&
                      _isSensitiveCategory(_selectedCategory!))
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.orange.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This is a sensitive report. '
                              'Please provide as much detail as possible.',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.orange.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Text('Description',
                      style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937))),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _descController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText:
                          'Describe the issue in detail...',
                      hintStyle: GoogleFonts.inter(
                          color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please describe the issue.';
                      }
                      if (v.trim().length < 20) {
                        return 'Please provide more detail (min 20 characters).';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      label: Text(
                        _submitting ? 'Submitting...' : 'Submit Report',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
