import 'dart:convert';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/teacher_manage_model.dart';
import '../providers/manage_teachers_provider.dart';

/// Add / edit a teacher record (Module 1 — Teacher Record).
///
/// Used both by the Principal (editing any teacher) and by a teacher editing
/// their own profile. Pass the target [teacherId].
class TeacherRecordFormView extends StatefulWidget {
  final String teacherId;

  const TeacherRecordFormView({super.key, required this.teacherId});

  @override
  State<TeacherRecordFormView> createState() => _TeacherRecordFormViewState();
}

class _TeacherRecordFormViewState extends State<TeacherRecordFormView> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _icController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  static const _genders = ['Male', 'Female'];
  static const _maritalStatuses = ['Single', 'Married', 'Divorced', 'Widowed'];

  String? _gender;
  String? _maritalStatus;
  DateTime? _dateOfBirth;

  /// Document checklist: true = teacher has submitted this document.
  final Map<String, bool> _documents = {
    for (final slot in TeacherManageModel.documentSlots) slot: false,
  };

  final Map<String, String> _documentUrls = {
    for (final slot in TeacherManageModel.documentSlots) slot: '',
  };

  final Map<String, bool> _uploadingDocs = {
    for (final slot in TeacherManageModel.documentSlots) slot: false,
  };
  final Map<String, String> _pickedNames = {
    for (final slot in TeacherManageModel.documentSlots) slot: '',
  };

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadRecord();
  }

  Future<void> _loadRecord() async {
    final provider = context.read<ManageTeachersProvider>();
    try {
      final record = await provider.streamTeacher(widget.teacherId).first;
      if (record != null) {
        _nameController.text = record.name;
        _emailController.text = record.email;
        _icController.text = record.icNumber ?? '';
        _addressController.text = record.address ?? '';
        _phoneController.text = record.phoneNumber ?? '';
        _emergencyNameController.text = record.emergencyContactName ?? '';
        _emergencyPhoneController.text = record.emergencyContactPhone ?? '';
        _gender = _genders.contains(record.gender) ? record.gender : null;
        _maritalStatus = _maritalStatuses.contains(record.maritalStatus)
            ? record.maritalStatus
            : null;
        _dateOfBirth = record.dateOfBirth;
        for (final slot in TeacherManageModel.documentSlots) {
          _documents[slot] = record.documents[slot] ?? false;
          _documentUrls[slot] = record.documentUrls[slot] ?? '';
        }
      }
    } catch (_) {
      // Leave fields empty; the form still works for a fresh record.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _contentTypeFor(String filename) {
    final lowerName = filename.toLowerCase();
    if (lowerName.endsWith('.pdf')) return 'application/pdf';
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerName.endsWith('.doc')) return 'application/msword';
    if (lowerName.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return 'application/octet-stream';
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
          _snack('Error loading document: $e');
        }
        return;
      }
    }

    if (!context.mounted) return;

    if (!actualUrl.startsWith('data:') && !actualUrl.startsWith('http://') && !actualUrl.startsWith('https://')) {
      _snack('Invalid or empty document content.');
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
                        _snack('Could not download or open document.');
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

  Future<void> _pickAndUploadFile(String slot) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
        withData: true,
      );
      if (result != null && result.files.single.bytes != null) {
        final file = result.files.single;
        
        setState(() {
          _uploadingDocs[slot] = true;
          _pickedNames[slot] = file.name;
        });

        final bytes = file.bytes!;
        final base64Str = base64Encode(bytes);
        final mimeType = _contentTypeFor(file.name);
        final dataUrl = 'data:$mimeType;base64,$base64Str';

        // Write to Firestore collection "user_documents" immediately
        await FirebaseFirestore.instance
            .collection('user_documents')
            .doc('${widget.teacherId}_$slot')
            .set({'url': dataUrl});

        setState(() {
          _documentUrls[slot] = 'user_documents/${widget.teacherId}_$slot';
          _documents[slot] = true;
          _uploadingDocs[slot] = false;
        });
      }
    } catch (e) {
      setState(() {
        _uploadingDocs[slot] = false;
        _pickedNames[slot] = '';
      });
      _snack('Upload failed: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _icController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null || _maritalStatus == null || _dateOfBirth == null) {
      _snack('Please complete gender, marital status and date of birth.');
      return;
    }

    final isUploadingAny = _uploadingDocs.values.any((v) => v == true);
    if (isUploadingAny) {
      _snack('Please wait for all file uploads to complete.');
      return;
    }

    final provider = context.read<ManageTeachersProvider>();
    setState(() => _saving = true);

    try {
      // Merge documents checklist with URLs:
      // If we have a URL, store the URL string. If not, keep whatever was there.
      final finalDocs = <String, dynamic>{};
      for (final slot in TeacherManageModel.documentSlots) {
        if (_documentUrls[slot] != null && _documentUrls[slot]!.isNotEmpty) {
          finalDocs[slot] = _documentUrls[slot];
        } else {
          finalDocs[slot] = _documents[slot] ?? false;
        }
      }

      // Check if all document checklist items are complete
      final hasAllDocs = TeacherManageModel.documentSlots.every((slot) =>
          (finalDocs[slot] is String && (finalDocs[slot] as String).isNotEmpty) ||
          (finalDocs[slot] is bool && finalDocs[slot] == true));

      if (!hasAllDocs) {
        throw Exception('You must upload all documents in the checklist.');
      }

      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'icNumber': _icController.text.trim(),
        'gender': _gender,
        'dateOfBirth': Timestamp.fromDate(_dateOfBirth!),
        'address': _addressController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'maritalStatus': _maritalStatus,
        'emergencyContact': <String, dynamic>{
          'name': _emergencyNameController.text.trim(),
          'phone': _emergencyPhoneController.text.trim(),
        },
        'documents': finalDocs,
      };

      final success = await provider.saveRecord(widget.teacherId, data);

      if (!mounted) return;
      if (success) {
        _snack('Teacher record saved.');
        Navigator.pop(context);
      } else {
        _snack(provider.errorMessage ?? 'Failed to save record.');
      }
    } catch (e) {
      if (mounted) _snack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          'Teacher Record',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Personal Information'),
                        const SizedBox(height: 12),
                        _textField(_nameController, 'Full Name',
                            icon: Icons.person_outline),
                        const SizedBox(height: 16),
                        _textField(
                          _icController,
                          'IC Number',
                          icon: Icons.badge_outlined,
                          keyboardType: TextInputType.number,
                          hint: '990101-14-5678',
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return 'Required';
                            if (!RegExp(r'^\d{6}-\d{2}-\d{4}$').hasMatch(t)) {
                              return 'Format: 990101-14-5678';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _dropdown(
                          label: 'Gender',
                          value: _gender,
                          items: _genders,
                          icon: Icons.wc_outlined,
                          onChanged: (v) => setState(() => _gender = v),
                        ),
                        const SizedBox(height: 16),
                        _dateField(),
                        const SizedBox(height: 16),
                        _dropdown(
                          label: 'Marital Status',
                          value: _maritalStatus,
                          items: _maritalStatuses,
                          icon: Icons.favorite_outline,
                          onChanged: (v) => setState(() => _maritalStatus = v),
                        ),
                        const SizedBox(height: 24),

                        _sectionTitle('Contact Information'),
                        const SizedBox(height: 12),
                        _textField(
                          _emailController,
                          'Email Address',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return 'Required';
                            if (!t.contains('@')) return 'Invalid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _textField(
                          _phoneController,
                          'Phone Number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        _textField(
                          _addressController,
                          'Address',
                          icon: Icons.home_outlined,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),

                        _sectionTitle('Emergency Contact'),
                        const SizedBox(height: 12),
                        _textField(
                          _emergencyNameController,
                          'Contact Person',
                          icon: Icons.contact_emergency_outlined,
                        ),
                        const SizedBox(height: 16),
                        _textField(
                          _emergencyPhoneController,
                          'Contact Number',
                          icon: Icons.phone_in_talk_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 24),

                        _sectionTitle('Documents Checklist'),
                        const SizedBox(height: 4),
                        Text(
                          'Tick each document that has been submitted.',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 12),
                        ...TeacherManageModel.documentSlots
                            .map(_buildChecklistRow),
                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _saving
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : Text(
                                    'Save Record',
                                    style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
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

  Widget _sectionTitle(String text) => Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1F2937),
        ),
      );

  Widget _textField(
    TextEditingController controller,
    String label, {
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: validator ?? (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  Widget _dateField() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date of Birth',
          prefixIcon: const Icon(Icons.cake_outlined),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          _dateOfBirth == null
              ? 'Select date'
              : DateFormat('MMM d, yyyy').format(_dateOfBirth!),
          style: GoogleFonts.inter(
            color:
                _dateOfBirth == null ? Colors.grey.shade600 : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistRow(String slot) {
    final label = TeacherManageModel.documentLabels[slot] ?? slot;
    final url = _documentUrls[slot] ?? '';
    final pickedName = _pickedNames[slot] ?? '';
    final isUploading = _uploadingDocs[slot] == true;
    final hasUploaded = url.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isUploading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (hasUploaded)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Uploaded',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Missing',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (pickedName.isNotEmpty && isUploading)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Uploading: $pickedName',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasUploaded) ...[
                  OutlinedButton.icon(
                    onPressed: () => _viewDocument(context, url, TeacherManageModel.documentLabels[slot] ?? slot),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('View'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton.icon(
                  onPressed: isUploading ? null : () => _pickAndUploadFile(slot),
                  icon: const Icon(Icons.upload_file, size: 14, color: Colors.white),
                  label: Text(hasUploaded ? 'Change File' : 'Upload File', style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
