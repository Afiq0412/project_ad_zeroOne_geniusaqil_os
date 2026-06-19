import 'dart:convert';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:file_picker/file_picker.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/training_provider.dart';
import '../models/training_model.dart';

class TrainingFormView extends StatefulWidget {
  final TrainingModel? logToEdit;
  final bool isViewOnly;

  const TrainingFormView({super.key, this.logToEdit, this.isViewOnly = false});

  @override
  State<TrainingFormView> createState() => _TrainingFormViewState();
}

class _TrainingFormViewState extends State<TrainingFormView> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _organizerController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _reflectionController = TextEditingController();
  String? _certificateUrl;
  PlatformFile? _pickedCertificate;
  List<String> _photoUrls = [];
  List<PlatformFile> _pickedPhotos = [];

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
  String _selectedMode = 'Physical';
  DateTime _selectedDate = DateTime.now();

  bool _uploading = false;

  bool get isEditing => widget.logToEdit != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _titleController.text = widget.logToEdit!.title;
      _organizerController.text = widget.logToEdit!.organizer;
      _durationController.text = widget.logToEdit!.duration.toString();
      _venueController.text = widget.logToEdit!.venue;
      _reflectionController.text = widget.logToEdit!.reflection;
      _selectedCategory = widget.logToEdit!.category;
      _selectedMode = widget.logToEdit!.mode;
      _selectedDate = widget.logToEdit!.date;

      _certificateUrl = widget.logToEdit!.certificateUrl;
      _photoUrls = List<String>.from(widget.logToEdit!.photoUrls ?? []);
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

  Future<void> _pickCertificate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
        withData: true,
      );
      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _pickedCertificate = result.files.single;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _pickedPhotos.add(result.files.single);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking photo: $e')),
      );
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

  // Function to view/download URLs
  Future<void> _launchURL(String urlString) async {
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
        if (mounted) Navigator.pop(context); // Close loading indicator
        
        final fetched = doc.data()?['url'] as String?;
        if (fetched == null || fetched.isEmpty) {
          throw Exception('Document content is empty.');
        }
        actualUrl = fetched.trim();
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading indicator in case of error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading document: $e')),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    if (!actualUrl.startsWith('data:') && !actualUrl.startsWith('http://') && !actualUrl.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid or empty attachment link.')),
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
                child: Text('Attachment Image', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
                child: Text('Attachment Document', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
                        ..download = 'attachment' + (isPdf ? '.pdf' : '');
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    final trainingProvider =
        Provider.of<TrainingProvider>(context, listen: false);
    final user =
        Provider.of<AuthProvider>(context, listen: false).currentUserModel!;

    setState(() => _uploading = true);

    try {
      final String trainingId = widget.logToEdit?.id ?? FirebaseFirestore.instance.collection('training_logs').doc().id;

      // 1. Convert certificate if newly picked
      if (_pickedCertificate != null) {
        final bytes = _pickedCertificate!.bytes!;
        final mimeType = _contentTypeFor(_pickedCertificate!.name);
        final base64Str = base64Encode(bytes);
        final dataUrl = 'data:$mimeType;base64,$base64Str';

        await FirebaseFirestore.instance
            .collection('user_documents')
            .doc('training_cert_$trainingId')
            .set({'url': dataUrl});

        _certificateUrl = 'user_documents/training_cert_$trainingId';
      }

      // 2. Convert photo files if newly picked
      final uploadedPhotoUrls = List<String>.from(_photoUrls);
      for (int i = 0; i < _pickedPhotos.length; i++) {
        final photoFile = _pickedPhotos[i];
        final bytes = photoFile.bytes!;
        final mimeType = _contentTypeFor(photoFile.name);
        final base64Str = base64Encode(bytes);
        final dataUrl = 'data:$mimeType;base64,$base64Str';

        final photoIndex = uploadedPhotoUrls.length;
        final docId = 'training_photo_${trainingId}_$photoIndex';

        await FirebaseFirestore.instance
            .collection('user_documents')
            .doc(docId)
            .set({'url': dataUrl});

        uploadedPhotoUrls.add('user_documents/$docId');
      }

      final training = TrainingModel(
        id: trainingId,
        teacherId: isEditing ? widget.logToEdit!.teacherId : user.id,
        title: _titleController.text.trim(),
        category: _selectedCategory!,
        organizer: _organizerController.text.trim(),
        date: _selectedDate,
        duration: double.parse(_durationController.text.trim()),
        mode: _selectedMode,
        venue: _venueController.text.trim(),
        reflection: _reflectionController.text.trim(),
        certificateUrl: _certificateUrl,
        photoUrls: uploadedPhotoUrls.isNotEmpty ? uploadedPhotoUrls : null,
        createdAt: isEditing ? widget.logToEdit!.createdAt : DateTime.now(),
      );

      bool success;
      if (isEditing) {
        success = await trainingProvider.updateTraining(training);
      } else {
        success = await trainingProvider.addTraining(training);
      }

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  isEditing
                      ? 'Log updated successfully!'
                      : 'Log saved successfully!',
                  style: GoogleFonts.inter())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainingProvider = Provider.of<TrainingProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          widget.isViewOnly
              ? 'View Log Details'
              : (isEditing ? 'Edit Log' : 'New Log'),
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 0,
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Training Details',
                      style: GoogleFonts.outfit(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _titleController,
                    readOnly: widget.isViewOnly,
                    decoration: InputDecoration(
                      labelText: 'Training Title',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.title),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.category),
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: widget.isViewOnly
                        ? null
                        : (v) => setState(() => _selectedCategory = v),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _organizerController,
                    readOnly: widget.isViewOnly,
                    decoration: InputDecoration(
                      labelText: 'Organizer',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.business),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: widget.isViewOnly
                              ? null
                              : () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null)
                                    setState(() => _selectedDate = picked);
                                },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.calendar_today),
                            ),
                            child: Text(DateFormat('dd MMM yyyy')
                                .format(_selectedDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _durationController,
                          readOnly: widget.isViewOnly,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Duration (Hrs)',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.timer),
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _selectedMode,
                    decoration: InputDecoration(
                      labelText: 'Mode',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.laptop_chromebook),
                    ),
                    items: ['Physical', 'Online', 'Hybrid']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: widget.isViewOnly
                        ? null
                        : (v) => setState(() => _selectedMode = v!),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _venueController,
                    readOnly: widget.isViewOnly,
                    decoration: InputDecoration(
                      labelText: 'Venue / Platform',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.location_on),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _reflectionController,
                    readOnly: widget.isViewOnly,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Reflection / Key Takeaways',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  // --- ATTACHMENTS SECTION ---
                  const Divider(height: 48),
                  Text('Attachments',
                      style: GoogleFonts.outfit(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // --- CERTIFICATE UPLOAD ---
                  Text('Certificate (PDF, Image, or Word)',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  if (widget.isViewOnly) ...[
                    if (_certificateUrl != null && _certificateUrl!.isNotEmpty)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300)),
                        leading: const Icon(Icons.verified_user, color: Colors.green),
                        title: Text('Certificate File',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                        trailing: OutlinedButton.icon(
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: const Text('Open'),
                          onPressed: () => _launchURL(_certificateUrl!),
                        ),
                      )
                    else
                      Text('No certificate attached',
                          style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)),
                  ] else ...[
                    if (_certificateUrl != null && _certificateUrl!.isNotEmpty) ...[
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300)),
                        leading: const Icon(Icons.check_circle, color: Colors.green),
                        title: Text('Current Certificate',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.open_in_new, color: Colors.blue),
                              onPressed: () => _launchURL(_certificateUrl!),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _certificateUrl = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_pickedCertificate != null) ...[
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.blue.shade300)),
                        leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                        title: Text(_pickedCertificate!.name,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontStyle: FontStyle.italic)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _pickedCertificate = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_certificateUrl == null && _pickedCertificate == null)
                      ElevatedButton.icon(
                        onPressed: _uploading ? null : _pickCertificate,
                        icon: const Icon(Icons.upload_file, color: Colors.white),
                        label: const Text('Upload Certificate', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                  ],

                  const SizedBox(height: 24),

                  // --- ACTIVITY PHOTOS UPLOAD ---
                  Text('Activity Photos (Images only)',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  if (widget.isViewOnly) ...[
                    if (_photoUrls.isNotEmpty)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _photoUrls.length,
                        itemBuilder: (context, index) {
                          final url = _photoUrls[index];
                          return InkWell(
                            onTap: () => _launchURL(url),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image, size: 40)),
                              ),
                            ),
                          );
                        },
                      )
                    else
                      Text('No photos attached',
                          style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)),
                  ] else ...[
                    // List existing photos
                    if (_photoUrls.isNotEmpty) ...[
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _photoUrls.length,
                        itemBuilder: (context, index) {
                          final url = _photoUrls[index];
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: DocumentImageWidget(
                                    url: url,
                                    fit: BoxFit.cover,
                                    placeholder: const Center(child: Icon(Icons.image, size: 40)),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.red.withValues(alpha: 0.8),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        _photoUrls.removeAt(index);
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    // List picked photos ready to upload
                    if (_pickedPhotos.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _pickedPhotos.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final f = entry.value;
                          return Chip(
                            avatar: const Icon(Icons.image, size: 16, color: Colors.blue),
                            label: Text(f.name, style: const TextStyle(fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              setState(() {
                                _pickedPhotos.removeAt(idx);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    ElevatedButton.icon(
                      onPressed: _uploading ? null : _pickPhoto,
                      icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
                      label: const Text('Add Activity Photo', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Hide Submit button entirely for Principal
                  if (!widget.isViewOnly)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            (_uploading || trainingProvider.isLoading) ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: (_uploading || trainingProvider.isLoading)
                            ? const CircularProgressIndicator(
                                color: Colors.white)
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

class DocumentImageWidget extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final Widget placeholder;

  const DocumentImageWidget({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholder = const Center(child: Icon(Icons.image, size: 40)),
  });

  Future<String> _fetchUrl() async {
    final trimmed = url.trim();
    if (trimmed.startsWith('user_documents/') || trimmed.startsWith('/user_documents/')) {
      final docPath = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
      final doc = await FirebaseFirestore.instance.doc(docPath).get();
      final fetched = doc.data()?['url'] as String?;
      if (fetched == null || fetched.isEmpty) {
        throw Exception('Document content is empty');
      }
      return fetched;
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return placeholder;

    if (!trimmed.startsWith('user_documents/') && !trimmed.startsWith('/user_documents/')) {
      return Image.network(
        trimmed,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    return FutureBuilder<String>(
      future: _fetchUrl(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return placeholder;
        }
        return Image.network(
          snapshot.data!,
          fit: fit,
          errorBuilder: (_, __, ___) => placeholder,
        );
      },
    );
  }
}
