import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/training_provider.dart';
import '../models/training_model.dart';
import '../services/training_service.dart';

class TrainingFormView extends StatefulWidget {
  const TrainingFormView({super.key});

  @override
  State<TrainingFormView> createState() => _TrainingFormViewState();
}

class _TrainingFormViewState extends State<TrainingFormView> {
  final _formKey = GlobalKey<FormState>();
  final TrainingService _trainingService = TrainingService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _organizerController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _reflectionController = TextEditingController();

  final List<String> _categories = [
    'Teaching Skills', 'Child Development', 'Safety and First Aid',
    'Islamic Education', 'Classroom Management', 'ICT/Technology', 'Others'
  ];

  String? _selectedCategory;
  DateTime? _selectedDate;
  String _selectedMode = 'Physical';
  
  File? _certificateFile;
  File? _photoFile;

  @override
  void dispose() {
    _titleController.dispose();
    _organizerController.dispose();
    _durationController.dispose();
    _venueController.dispose();
    _reflectionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Theme.of(context).colorScheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickAssetFile(bool isCertificate) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      setState(() {
        if (isCertificate) {
          _certificateFile = File(result.files.single.path!);
        } else {
          _photoFile = File(result.files.single.path!);
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill out all the fields and pick a date.', style: GoogleFonts.inter()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final trainingProvider = Provider.of<TrainingProvider>(context, listen: false);
    final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel!;
    
    String? certUrl;
    String? photoUrl;
    String uniqueKey = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      if (_certificateFile != null) {
        certUrl = await _trainingService.uploadFile(_certificateFile!, 'certificates', '${user.id}_cert_$uniqueKey');
      }
      if (_photoFile != null) {
        photoUrl = await _trainingService.uploadFile(_photoFile!, 'photos', '${user.id}_photo_$uniqueKey');
      }

      TrainingModel training = TrainingModel(
        teacherId: user.id,
        title: _titleController.text.trim(),
        category: _selectedCategory!,
        organizer: _organizerController.text.trim(),
        date: _selectedDate!,
        duration: double.tryParse(_durationController.text.trim()) ?? 0,
        mode: _selectedMode,
        venue: _venueController.text.trim(),
        reflection: _reflectionController.text.trim(),
        certificateUrl: certUrl,
        photoUrl: photoUrl,
        createdAt: DateTime.now(),
      );

      bool success = await trainingProvider.addTraining(training);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Log Added Successfully!', style: GoogleFonts.inter())),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e', style: GoogleFonts.inter())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainingProvider = Provider.of<TrainingProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text('Log Activity', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Training Title',
                      labelStyle: GoogleFonts.inter(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.inter()))).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            _selectedDate == null ? 'Select Date' : DateFormat('MMM d, yyyy').format(_selectedDate!),
                            style: GoogleFonts.inter(),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _organizerController,
                    decoration: InputDecoration(
                      labelText: 'Organizer',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Duration (Hours)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedMode,
                    items: ['Physical', 'Online'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setState(() => _selectedMode = v!),
                    decoration: InputDecoration(
                      labelText: 'Mode',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _venueController,
                    decoration: InputDecoration(
                      labelText: 'Venue / Platform',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reflectionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Reflection / Key Takeaways',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickAssetFile(true),
                          icon: Icon(_certificateFile == null ? Icons.upload_file : Icons.check_circle),
                          label: Text(_certificateFile == null ? 'Attach Cert' : 'Cert Added'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickAssetFile(false),
                          icon: Icon(_photoFile == null ? Icons.add_a_photo : Icons.check_circle),
                          label: Text(_photoFile == null ? 'Attach Photo' : 'Photo Added'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: trainingProvider.isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: trainingProvider.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Save Log',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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