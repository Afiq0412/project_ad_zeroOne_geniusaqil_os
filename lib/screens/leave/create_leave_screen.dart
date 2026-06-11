import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_provider.dart';

class CreateLeaveScreen extends StatefulWidget {
  const CreateLeaveScreen({super.key});

  @override
  State<CreateLeaveScreen> createState() => _CreateLeaveScreenState();
}

class _CreateLeaveScreenState extends State<CreateLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  String _selectedLeaveType = 'Annual leave';
  String? _medicalCertBase64;
  String? _medicalCertFileName;

  final List<String> _leaveTypes = [
    'Annual leave',
    'Medical leave (MC)',
    'Unpaid leave',
    'Maternity leave',
    'Marriage leave',
    'Compassionate leave',
    'Umrah leave',
    'Haji leave',
    'Birthday leave',
    'Half day leave',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _pickMedicalCertificate() {
    if (!kIsWeb) return;
    final html.FileUploadInputElement input = html.FileUploadInputElement();
    input.accept = 'image/*,application/pdf';
    input.click();
    input.onChange.listen((event) {
      if (input.files!.isEmpty) return;
      final file = input.files!.first;
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoadEnd.listen((loadEndEvent) {
        setState(() {
          _medicalCertBase64 = reader.result as String?;
          _medicalCertFileName = file.name;
        });
      });
    });
  }

  void _pickDateRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  double _calculateDaysCount() {
    if (_selectedDateRange == null) return 0.0;
    final int days = _selectedDateRange!.end.difference(_selectedDateRange!.start).inDays + 1;
    if (_selectedLeaveType == 'Half day leave') {
      return days * 0.5;
    }
    return days.toDouble();
  }

  void _submit() async {
    if (_formKey.currentState!.validate() && _selectedDateRange != null) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
      final user = authProvider.currentUserModel!;

      final double requestedDays = _calculateDaysCount();
      final double currentBalance = user.leaveBalances[_selectedLeaveType] ?? 0.0;

      if (_selectedLeaveType == 'Half day leave') {
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1));

        final snapshot = await FirebaseFirestore.instance
            .collection('leave_requests')
            .where('userId', isEqualTo: user.id)
            .where('leaveType', isEqualTo: 'Half day leave')
            .get();

        final currentMonthRequests = snapshot.docs.where((doc) {
          final data = doc.data();
          final createdAt = (data['createdAt'] as Timestamp).toDate();
          final status = data['status'] ?? 'Pending';
          return createdAt.isAfter(startOfMonth) &&
              createdAt.isBefore(endOfMonth) &&
              status != 'Rejected';
        }).length;

        if (currentMonthRequests >= 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient balance. You can only apply for Half day leave at most 2 times per month.',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      } else {
        if (requestedDays > currentBalance) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient balance. You only have $currentBalance days of $_selectedLeaveType remaining.',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      if (_selectedLeaveType == 'Medical leave (MC)' && _medicalCertBase64 == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Medical Certificate (MC) is required for Medical leave.',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final success = await leaveProvider.submitLeave(
        userId: user.id,
        userName: user.name,
        start: _selectedDateRange!.start,
        end: _selectedDateRange!.end,
        reason: _reasonController.text.trim(),
        leaveType: _selectedLeaveType,
        daysCount: requestedDays,
        medicalCert: _medicalCertBase64,
      );

      if (success && mounted) {
        await authProvider.refreshUser();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Leave request submitted successfully!')),
          );
          Navigator.pop(context);
        }
      }
    } else if (_selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date range for your leave.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaveProvider = Provider.of<LeaveProvider>(context);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text('Request Leave', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
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
              if (leaveProvider.errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    leaveProvider.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              Text(
                'Leave Type',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedLeaveType,
                decoration: InputDecoration(
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                items: _leaveTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type, style: GoogleFonts.inter()),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedLeaveType = val!;
                    if (_selectedLeaveType != 'Medical leave (MC)') {
                      _medicalCertBase64 = null;
                      _medicalCertFileName = null;
                    }
                  });
                },
              ),
              if (_selectedLeaveType == 'Medical leave (MC)') ...[
                const SizedBox(height: 24),
                Text(
                  'Medical Certificate (MC) *',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickMedicalCertificate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: _medicalCertBase64 != null ? Colors.green : Colors.grey.shade300,
                        width: _medicalCertBase64 != null ? 2.0 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _medicalCertBase64 != null ? Icons.check_circle : Icons.upload_file,
                          color: _medicalCertBase64 != null ? Colors.green : Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _medicalCertFileName ?? 'Upload Medical Certificate (Image/PDF)',
                            style: GoogleFonts.inter(
                              color: _medicalCertFileName == null ? Colors.grey : Colors.black87,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Leave Duration',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDateRange,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _selectedDateRange == null
                              ? 'Select Date Range'
                              : '${dateFormat.format(_selectedDateRange!.start)} - ${dateFormat.format(_selectedDateRange!.end)} (${_calculateDaysCount()} day(s))',
                          style: GoogleFonts.inter(
                            color: _selectedDateRange == null ? Colors.grey : Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Reason for Leave',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Please provide a detailed reason...',
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Please enter a reason' : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: leaveProvider.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: leaveProvider.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Submit Request',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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
