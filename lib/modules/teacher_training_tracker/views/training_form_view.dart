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

  // Dropdown options
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.orange.shade600),
          ),
          child: child!,
        );
      },
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
        SnackBar(
          content: const Text('Oops! Please fill out all the fields and pick a date. 🎈'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
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
        SnackBar(
          content: const Text('Yay! Training session logged successfully! 🎉'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Oh no, failed to save. Please try again!'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Friendly input decoration helper
  InputDecoration _friendlyDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.orange.shade400),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.orange.shade100, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.orange.shade400, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log New Activity 📝')),
      body: _isLoading 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.orange.shade600),
                const SizedBox(height: 16),
                const Text('Saving your wonderful progress...', style: TextStyle(fontSize: 16)),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: _friendlyDecoration('Course Name or Title *', Icons.local_activity_rounded),
                    validator: (v) => v!.isEmpty ? 'Please tell us the name! 🌟' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: _friendlyDecoration('Select Category *', Icons.category_rounded),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val),
                    validator: (v) => v == null ? 'Please pick one! 🎈' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _organizerController,
                    decoration: _friendlyDecoration('Organizer (Who held it?) *', Icons.groups_rounded),
                    validator: (v) => v!.isEmpty ? 'Field required' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.shade100, width: 2),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, color: Colors.orange.shade400),
                          const SizedBox(width: 12),
                          Text(
                            _selectedDate == null 
                                ? 'Pick a Date *' 
                                : 'Date: ${DateFormat('MMMM dd, yyyy').format(_selectedDate!)}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: _friendlyDecoration('Duration (How many hours?) *', Icons.timer_rounded),
                    validator: (v) => v!.isEmpty ? 'Field required' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.shade100, width: 2),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.place_rounded, color: Colors.orange.shade400),
                        const SizedBox(width: 8),
                        const Text('Mode:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Radio<String>(
                          value: 'Physical',
                          groupValue: _selectedMode,
                          activeColor: Colors.orange.shade600,
                          onChanged: (v) => setState(() => _selectedMode = v!),
                        ),
                        const Text('In Person'),
                        Radio<String>(
                          value: 'Online',
                          groupValue: _selectedMode,
                          activeColor: Colors.orange.shade600,
                          onChanged: (v) => setState(() => _selectedMode = v!),
                        ),
                        const Text('Online'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _venueController,
                    decoration: _friendlyDecoration('Venue / Online Platform *', Icons.computer_rounded),
                    validator: (v) => v!.isEmpty ? 'Field required' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _reflectionController,
                    maxLines: 3,
                    decoration: _friendlyDecoration('What was your biggest takeaway? 💡 *', Icons.lightbulb_rounded),
                    validator: (v) => v!.isEmpty ? 'Please share your thoughts!' : null,
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: _certificateFile == null ? Colors.orange.shade300 : Colors.green),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: () => _pickAssetFile(true),
                          icon: Icon(_certificateFile == null ? Icons.upload_file_rounded : Icons.check_circle_rounded, 
                                     color: _certificateFile == null ? Colors.orange.shade600 : Colors.green),
                          label: Text(_certificateFile == null ? 'Attach Cert' : 'Cert Added!'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: _photoFile == null ? Colors.orange.shade300 : Colors.green),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: () => _pickAssetFile(false),
                          icon: Icon(_photoFile == null ? Icons.add_a_photo_rounded : Icons.check_circle_rounded, 
                                     color: _photoFile == null ? Colors.orange.shade600 : Colors.green),
                          label: Text(_photoFile == null ? 'Add Photo' : 'Photo Added!'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 4,
                      ),
                      onPressed: _submitForm,
                      icon: const Icon(Icons.send_rounded, size: 24),
                      label: const Text('Save My Adventure!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
    );
  }
}