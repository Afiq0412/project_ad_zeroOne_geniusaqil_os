import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/performance_model.dart';
import '../../providers/performance_provider.dart';
import 'performance_tracker_screen.dart';
import 'performance_history_screen.dart';

class StartReviewScreen extends StatefulWidget {
  final Teacher teacher;
  const StartReviewScreen({super.key, required this.teacher});

  @override
  State<StartReviewScreen> createState() => _StartReviewScreenState();
}

class _StartReviewScreenState extends State<StartReviewScreen> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _periodController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default period to current month/year
    final now = DateTime.now();
    _periodController.text =
        '${_monthName(now.month)} ${now.year}';
  }

  @override
  void dispose() {
    _periodController.dispose();
    super.dispose();
  }

  String _monthName(int month) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month];
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _periodController.text = '${_monthName(picked.month)} ${picked.year}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PerformanceProvider>();
    final evalCount =
        provider.getEvaluationCount(widget.teacher.id);

    return Scaffold(
      appBar: AppBar(title: Text('Evaluate ${widget.teacher.name}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Teacher info card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        widget.teacher.getInitials(),
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(widget.teacher.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$evalCount previous evaluation(s)',
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Evaluation settings card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Evaluation Settings',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // Date picker field
                    GestureDetector(
                      onTap: _pickDate,
                      child: AbsorbPointer(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Evaluation Date',
                            prefixIcon: const Icon(Icons.calendar_today),
                            hintText: _formatDate(_selectedDate),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          controller: TextEditingController(
                              text: _formatDate(_selectedDate)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Review period field
                    TextField(
                      controller: _periodController,
                      decoration: InputDecoration(
                        labelText: 'Review Period (e.g. April 2025)',
                        prefixIcon: const Icon(Icons.date_range),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Start evaluation button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  provider.startNewReview(
                    teacher: widget.teacher,
                    reviewPeriod: _periodController.text.trim().isEmpty
                        ? _formatDate(_selectedDate)
                        : _periodController.text.trim(),
                    evaluationDate: _selectedDate,
                    reviewerId: 'admin_001',        // TODO: replace with real auth
                    reviewerName: 'Dr. Norhanisah', // TODO: replace with real auth
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PerformanceTrackerScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Evaluation'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // View history button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: evalCount == 0
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PerformanceHistoryScreen(
                                teacherId: widget.teacher.id),
                          ),
                        ),
                icon: const Icon(Icons.history),
                label: Text('View All Records ($evalCount)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}