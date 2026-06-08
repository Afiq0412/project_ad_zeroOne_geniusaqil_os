import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/training_model.dart';
import '../services/training_service.dart';

class TrainingFormView extends StatefulWidget {
  final String teacherId;
  const TrainingFormView({Key? key, required this.teacherId}) : super(key: key);

  @override
  _TrainingFormViewState createState() => _TrainingFormViewState();
}

class _TrainingFormViewState extends State<TrainingFormView> {
  final _formKey = GlobalKey<FormState>();
  final TrainingService _trainingService = TrainingService();

  // Inputs Contollers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _organizerController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _reflectionController = TextEditingController();

  // Dropdown options [cite: 315]
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
  
  File? _certificateFile;
  File? _photoFile;
  bool _isLoading = false;

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
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
        const SnackBar(content: Text('Please fill all required inputs & choose a date')),
      );
      return;
    }

    setState(() => _isLoading = true);

    String? certUrl;
    String? photoUrl;
    String uniqueKey = DateTime.now().millisecondsSinceEpoch.toString();

    if (_certificateFile != null) {
      certUrl = await _trainingService.uploadFile(_certificateFile!, 'certificates', '${widget.teacherId}_cert_$uniqueKey');
    }
    if (_photoFile != null) {
      photoUrl = await _trainingService.uploadFile(_photoFile!, 'photos', '${widget.teacherId}_photo_$uniqueKey');
    }

    TrainingModel training = TrainingModel(
      teacherId: widget.teacherId,
      title: _titleController.text.trim(),
      category: _selectedCategory!,
      organizer: _organizerController.text.trim(),
      date: _selectedDate!,
      duration: double.parse(_durationController.text.trim()),
      mode: _selectedMode,
      venue: _venueController.text.trim(),
      reflection: _reflectionController.text.trim(),
      certificateUrl: certUrl,
      photoUrl: photoUrl,
      createdAt: DateTime.now(),
    );

    bool status = await _trainingService.submitTrainingLog(training);
    setState(() => _isLoading = false);

    if (status) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Training session logged successfully!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit log record.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Training Session')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Training Title / Course Name *'),
                    validator: (v) => v!.isEmpty ? 'Field required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    hint: const Text('Select Training Category *'),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val),
                    validator: (v) => v == null ? 'Field required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _organizerController,
                    decoration: const InputDecoration(labelText: 'Training Organizer *'),
                    validator: (v) => v!.isEmpty ? 'Field required' : null,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: Text(_selectedDate == null 
                        ? 'Select Training Date *' 
                        : 'Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Duration (Hours/Days) *'),
                    validator: (v) => v!.isEmpty ? 'Field required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Mode: ', style: TextStyle(fontSize: 16)),
                      Radio<String>(
                        value: 'Physical',
                        groupValue: _selectedMode,
                        onChanged: (v) => setState(() => _selectedMode = v!),
                      ),
                      const Text('Physical'),
                      Radio<String>(
                        value: 'Online',
                        groupValue: _selectedMode,
                        onChanged: (v) => setState(() => _selectedMode = v!),
                      ),
                      const Text('Online'),
                    ],
                  ),
                  TextFormField(
                    controller: _venueController,
                    decoration: const InputDecoration(labelText: 'Venue / Platform *'),
                    validator: (v) => v!.isEmpty ? 'Field required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reflectionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Reflection / Key Takeaways *'),
                    validator: (v) => v!.isEmpty ? 'Field required' : null,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _pickAssetFile(true),
                        icon: const Icon(Icons.upload_file),
                        label: Text(_certificateFile == null ? 'Upload Cert' : 'Cert Attached'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _pickAssetFile(false),
                        icon: const Icon(Icons.image),
                        label: Text(_photoFile == null ? 'Upload Photo' : 'Photo Attached'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                      onPressed: _submitForm,
                      child: const Text('Submit Logs Entry', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}