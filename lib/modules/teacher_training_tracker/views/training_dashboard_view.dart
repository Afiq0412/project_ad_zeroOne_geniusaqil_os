import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/training_model.dart';
import '../services/training_service.dart';
import 'training_form_view.dart';
import 'yearly_report_view.dart';

class TrainingDashboardView extends StatelessWidget {
  final String teacherId; // Assigned identifier context
  final String userRole;  // 'Teacher' or 'Admin'
  final TrainingService _service = TrainingService();

  TrainingDashboardView({Key? key, required this.teacherId, required this.userRole}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int currentYear = DateTime.now().year;

    return StreamBuilder<List<TrainingModel>>(
      stream: userRole == 'Admin' ? _service.streamAllTrainings() : _service.streamTeacherTrainings(teacherId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        List<TrainingModel> items = snapshot.data ?? [];
        
        // Count entries logged in the current calendar year
        int currentYearCount = items.where((element) => element.date.year == currentYear).length;
        double complianceProgress = (currentYearCount / 3.0).clamp(0.0, 1.0); // Target criteria metric = 3

        return Scaffold(
          appBar: AppBar(
            title: Text(userRole == 'Admin' ? '✨ Principal Dashboard' : '🌟 My Learning Journey'),
            actions: [
              IconButton(
                icon: const Icon(Icons.auto_awesome_mosaic_rounded, size: 28),
                tooltip: 'Yearly Summary',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => YearlyReportView(logs: items)),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Friendly Greeting
                Text(
                  userRole == 'Admin' ? 'Hello, Principal! 👋' : 'Welcome back, Teacher! 🍎',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                ),
                const SizedBox(height: 16),
                
                // Bubbly Progress Card
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 28),
                            const SizedBox(width: 8),
                            Text('$currentYear Learning Goals', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You have completed $currentYearCount out of 3 sessions!',
                          style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12), // Soft, rounded progress bar
                          child: LinearProgressIndicator(
                            value: complianceProgress,
                            minHeight: 18,
                            backgroundColor: Colors.orange.shade100,
                            color: complianceProgress >= 1.0 ? Colors.green.shade400 : Colors.orangeAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                Text('Recent Adventures 📚', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                const SizedBox(height: 12),
                
                // History List
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.nature_people_rounded, size: 64, color: Colors.orange.shade200),
                              const SizedBox(height: 16),
                              Text('No activities yet. Let\'s learn something new!', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final log = items[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: Colors.white,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange.shade100,
                                  child: Icon(Icons.school_rounded, color: Colors.orange.shade700),
                                ),
                                title: Text(log.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${log.category}\n${DateFormat('MMM dd, yyyy').format(log.date)}'),
                                isThreeLine: true,
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('${log.duration} hrs', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            );
                          },
                        ),
                )
              ],
            ),
          ),
          floatingActionButton: userRole == 'Teacher'
              ? FloatingActionButton.extended(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_reaction_rounded),
                  label: const Text('Add Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TrainingFormView(teacherId: teacherId)),
                  ),
                )
              : null,
        );
      },
    );
  }
}