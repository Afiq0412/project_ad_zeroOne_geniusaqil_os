import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
        }
      }
    } catch (_) {
      // Leave fields empty; the form still works for a fresh record.
    } finally {
      if (mounted) setState(() => _loading = false);
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

    final provider = context.read<ManageTeachersProvider>();
    setState(() => _saving = true);

    try {
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
        'documents': Map<String, dynamic>.from(_documents),
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
    final ticked = _documents[slot] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: CheckboxListTile(
        value: ticked,
        onChanged: (v) => setState(() => _documents[slot] = v ?? false),
        title: Text(label,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600, fontSize: 14)),
        secondary: Icon(
          ticked ? Icons.task_alt : Icons.radio_button_unchecked,
          color: ticked
              ? Colors.green
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        ),
        activeColor: Colors.green,
        checkColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }
}
