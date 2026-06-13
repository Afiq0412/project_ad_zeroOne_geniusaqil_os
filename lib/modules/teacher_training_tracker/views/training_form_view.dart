import 'dart:typed_data';
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
  final TrainingModel? logToEdit; // 👈 Accepts a log for editing

  const TrainingFormView({super.key, this.logToEdit});

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
    'Teaching Skills',
    'Child Development',
    'Safety and First Aid',
    'Islamic Education',
    'Classroom Management',
    'ICT/Technology',
    'Others'
  ];

  String? _selectedCategory;
  DateTime? _selectedDate;
  String _selectedMode = 'Physical';

  // File Management State
  PlatformFile? _certificate;
  List<PlatformFile> _photos = [];

  // Existing URLs (if editing)
  String? _existingCertUrl;
  List<String> _existingPhotoUrls = [];

  @override
  void initState() {
    super.initState();
    // Pre-fill data if we are editing an existing log
    if (widget.logToEdit != null) {
      final log = widget.logToEdit!;
      _titleController.text = log.title;
      _organizerController.text = log.organizer;
      _durationController.text = log.duration.toString();
      _venueController.text = log.venue;
      _reflectionController.text = log.reflection;

      _selectedCategory =
          _categories.contains(log.category) ? log.category : null;
      _selectedDate = log.date;
      _selectedMode = log.mode;

      _existingCertUrl = log.certificateUrl;
      _existingPhotoUrls = List.from(log.photoUrls ?? []);
    }
  }

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
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // 👈 New File Picker Logic for Web compatibility and multiple files
  Future<void> _pickAssetFile(bool isCertificate) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: isCertificate ? FileType.custom : FileType.image,
      allowedExtensions: isCertificate ? ['pdf', 'jpg', 'jpeg', 'png'] : null,
      allowMultiple: !isCertificate, // Allow multiple for photos
      withData: true, // MUST be true for Flutter Web
    );

    if (result != null) {
      setState(() {
        if (isCertificate) {
          _certificate = result.files.first;
          _existingCertUrl = null; // Clear old cert if uploading new one
        } else {
          _photos.addAll(result.files);
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Please fill all fields and date.',
                style: GoogleFonts.inter())),
      );
      return;
    }

    final trainingProvider =
        Provider.of<TrainingProvider>(context, listen: false);
    final user =
        Provider.of<AuthProvider>(context, listen: false).currentUserModel!;
    String uniqueKey = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      // 1. Upload new Certificate if added
      String? finalCertUrl = _existingCertUrl;
      if (_certificate != null && _certificate!.bytes != null) {
        finalCertUrl = await _trainingService.uploadFile(
            _certificate!.bytes!, 'certificates', '${user.id}_cert_$uniqueKey');
      }

      // 2. Upload multiple photos
      List<String> finalPhotos = List.from(_existingPhotoUrls);
      for (var photo in _photos) {
        if (photo.bytes != null) {
          String? url = await _trainingService.uploadFile(
              photo.bytes!,
              'photos',
              '${user.id}_photo_${DateTime.now().millisecondsSinceEpoch}');
          if (url != null) finalPhotos.add(url);
        }
      }

      TrainingModel training = TrainingModel(
        id: widget.logToEdit?.id, // Keep ID if updating
        teacherId: user.id,
        title: _titleController.text.trim(),
        category: _selectedCategory!,
        organizer: _organizerController.text.trim(),
        date: _selectedDate!,
        duration: double.tryParse(_durationController.text.trim()) ?? 0,
        mode: _selectedMode,
        venue: _venueController.text.trim(),
        reflection: _reflectionController.text.trim(),
        certificateUrl: finalCertUrl,
        photoUrls: finalPhotos,
        createdAt: widget.logToEdit?.createdAt ?? DateTime.now(),
      );

      bool success;
      if (widget.logToEdit == null) {
        success = await trainingProvider.addTraining(training);
      } else {
        success = await trainingProvider.updateTraining(training);
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Log Saved Successfully!', style: GoogleFonts.inter())),
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
    final isEditing = widget.logToEdit != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Activity' : 'Log Activity',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: Colors.white)),
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
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v),
                    decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_selectedDate == null
                        ? 'Select Date'
                        : DateFormat('MMM d, yyyy').format(_selectedDate!)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _organizerController,
                    decoration: InputDecoration(
                        labelText: 'Organizer',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: 'Duration (Hours)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedMode,
                    items: ['Physical', 'Online']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedMode = v!),
                    decoration: InputDecoration(
                        labelText: 'Mode',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _venueController,
                    decoration: InputDecoration(
                        labelText: 'Venue / Platform',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reflectionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                        labelText: 'Reflection / Key Takeaways',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),

                  // 👈 File Attachments UI Section
                  Text('Attachments',
                      style: GoogleFonts.outfit(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickAssetFile(true),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Add Cert'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickAssetFile(false),
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('Add Photos'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Show uploaded Certificate
                  if (_certificate != null)
                    Chip(
                      label: Text(_certificate!.name,
                          overflow: TextOverflow.ellipsis),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () => setState(() => _certificate = null),
                      backgroundColor: Colors.blue.shade50,
                    )
                  else if (_existingCertUrl != null)
                    Chip(
                      label: const Text('Existing Certificate Attached'),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () => setState(() => _existingCertUrl = null),
                      backgroundColor: Colors.green.shade50,
                    ),

                  // Show uploaded Photos
                  Wrap(
                    spacing: 8,
                    children: [
                      ..._existingPhotoUrls.map((url) => Chip(
                            label: const Text('Existing Photo'),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () =>
                                setState(() => _existingPhotoUrls.remove(url)),
                            backgroundColor: Colors.green.shade50,
                          )),
                      ..._photos.map((photo) => Chip(
                            label: Text(photo.name,
                                overflow: TextOverflow.ellipsis),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () =>
                                setState(() => _photos.remove(photo)),
                            backgroundColor: Colors.blue.shade50,
                          )),
                    ],
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed:
                          trainingProvider.isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: trainingProvider.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(isEditing ? 'Update Log' : 'Save Log',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
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
