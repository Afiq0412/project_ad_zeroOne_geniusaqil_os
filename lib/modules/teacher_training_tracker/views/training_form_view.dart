import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // 👈 Added for downloading/previewing
import '../../auth/providers/auth_provider.dart';
import '../providers/training_provider.dart';
import '../models/training_model.dart';

class TrainingFormView extends StatefulWidget {
  final TrainingModel? logToEdit;
  final bool isViewOnly; // 👈 Determines if Principal or Teacher

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
  final TextEditingController _certificateLinkController =
      TextEditingController();
  final TextEditingController _photoLinkController = TextEditingController();

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

  List<String> _photoLinks = [];

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

      _certificateLinkController.text = widget.logToEdit!.certificateUrl ?? '';
      _photoLinks = List<String>.from(widget.logToEdit!.photoUrls ?? []);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _organizerController.dispose();
    _durationController.dispose();
    _venueController.dispose();
    _reflectionController.dispose();
    _certificateLinkController.dispose();
    _photoLinkController.dispose();
    super.dispose();
  }

  // Function to view/download URLs
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the file link.')),
        );
      }
    }
  }

  Future<void> _copyLink(String urlString) async {
    await Clipboard.setData(ClipboardData(text: urlString));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied')),
    );
  }

  String? _optionalUrlValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Please enter a valid link';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'Link must start with http:// or https://';
    }

    return null;
  }

  void _addPhotoLink() {
    final link = _photoLinkController.text.trim();
    if (link.isEmpty) return;

    final error = _optionalUrlValidator(link);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    setState(() {
      _photoLinks.add(link);
      _photoLinkController.clear();
    });
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

    final certUrl = _certificateLinkController.text.trim();
    final pendingPhotoLink = _photoLinkController.text.trim();
    final finalPhotoUrls = List<String>.from(_photoLinks);

    if (pendingPhotoLink.isNotEmpty) {
      final error = _optionalUrlValidator(pendingPhotoLink);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        return;
      }
      finalPhotoUrls.add(pendingPhotoLink);
    }

    final training = TrainingModel(
      id: widget.logToEdit?.id,
      teacherId: isEditing ? widget.logToEdit!.teacherId : user.id,
      title: _titleController.text.trim(),
      category: _selectedCategory!,
      organizer: _organizerController.text.trim(),
      date: _selectedDate,
      duration: double.parse(_durationController.text.trim()),
      mode: _selectedMode,
      venue: _venueController.text.trim(),
      reflection: _reflectionController.text.trim(),
      certificateUrl: certUrl.isNotEmpty ? certUrl : null,
      photoUrls: finalPhotoUrls.isNotEmpty ? finalPhotoUrls : null,
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
                  // --- CERTIFICATE SECTION ---
                  const Divider(height: 48),
                  Text('Attachments',
                      style: GoogleFonts.outfit(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  if (widget.isViewOnly)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300)),
                      leading: const Icon(Icons.link, color: Colors.red),
                      title: Text('Certificate Link',
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w500)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _certificateLinkController.text.trim().isEmpty
                            ? Text('No certificate link',
                                style: GoogleFonts.inter(
                                    color: Colors.grey.shade700))
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SelectableText(
                                    _certificateLinkController.text.trim(),
                                    style: GoogleFonts.inter(fontSize: 13),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.copy, size: 18),
                                        label: const Text('Copy'),
                                        onPressed: () => _copyLink(
                                          _certificateLinkController.text
                                              .trim(),
                                        ),
                                      ),
                                      FilledButton.icon(
                                        icon: const Icon(Icons.open_in_new,
                                            size: 18),
                                        label: const Text('Open'),
                                        onPressed: () => _launchURL(
                                          _certificateLinkController.text
                                              .trim(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    )
                  else
                    TextFormField(
                      controller: _certificateLinkController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: 'Certificate Google Drive link',
                        hintText: 'https://drive.google.com/...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.link),
                        suffixIcon: _certificateLinkController.text
                                .trim()
                                .isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear link',
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _certificateLinkController.clear();
                                  });
                                },
                              ),
                      ),
                      validator: _optionalUrlValidator,
                      onChanged: (_) => setState(() {}),
                    ),

                  const SizedBox(height: 16),

                  Text('Activity Photo Google Drive Links',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),

                  if (!widget.isViewOnly)
                    Column(
                      children: [
                        TextFormField(
                          controller: _photoLinkController,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            labelText: 'Activity photo Google Drive link',
                            hintText: 'https://drive.google.com/...',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.link),
                            suffixIcon: IconButton(
                              tooltip: 'Attach link',
                              icon: const Icon(Icons.add_link),
                              onPressed: _addPhotoLink,
                            ),
                          ),
                          onFieldSubmitted: (_) => _addPhotoLink(),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.add_link),
                            onPressed: _addPhotoLink,
                            label: const Text('Attach Photo Link'),
                          ),
                        ),
                      ],
                    ),

                  if (_photoLinks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Column(
                      children: _photoLinks.asMap().entries.map((entry) {
                        final index = entry.key;
                        final url = entry.value;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            leading: const Icon(Icons.link),
                            title: Text('Photo Link ${index + 1}',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w500)),
                            subtitle: SelectableText(
                              url,
                              style: GoogleFonts.inter(fontSize: 13),
                            ),
                            trailing: widget.isViewOnly
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Copy photo link',
                                        icon: const Icon(Icons.copy),
                                        onPressed: () => _copyLink(url),
                                      ),
                                      IconButton(
                                        tooltip: 'Open photo link',
                                        icon: const Icon(Icons.open_in_new),
                                        onPressed: () => _launchURL(url),
                                      ),
                                    ],
                                  )
                                : IconButton(
                                    tooltip: 'Remove photo link',
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      setState(() {
                                        _photoLinks.removeAt(index);
                                      });
                                    },
                                  ),
                          ),
                        );
                      }).toList(),
                    ),
                  ] else if (widget.isViewOnly) ...[
                    Text('No activity photo links',
                        style: GoogleFonts.inter(color: Colors.grey.shade700)),
                  ],

                  const SizedBox(height: 32),

                  // Hide Submit button entirely for Principal
                  if (!widget.isViewOnly)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            trainingProvider.isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: trainingProvider.isLoading
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
