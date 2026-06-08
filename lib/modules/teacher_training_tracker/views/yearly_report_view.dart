import 'package:flutter/material.dart';
import '../models/training_model.dart';

class YearlyReportView extends StatelessWidget {
  final List<TrainingModel> logs;

  const YearlyReportView({Key? key, required this.logs}) : super(key: key);

  Map<int, List<TrainingModel>> _groupLogsByYear() {
    Map<int, List<TrainingModel>> grouped = {};
    for (var log in logs) {
      int year = log.date.year;
      if (!grouped.containsKey(year)) {
        grouped[year] = [];
      }
      grouped[year]!.add(log);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    var groupedData = _groupLogsByYear();
    var sortedYears = groupedData.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('My Memory Book 📖')),
      body: sortedYears.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_stories_rounded, size: 64, color: Colors.orange.shade200),
                  const SizedBox(height: 16),
                  Text('No stories written here yet.', style: TextStyle(color: Colors.grey.shade600, fontSize: 18)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedYears.length,
              itemBuilder: (context, idx) {
                int year = sortedYears[idx];
                List<TrainingModel> yearLogs = groupedData[year]!;
                double totalHours = yearLogs.fold(
                  0,
                  (sum, item) => sum + item.duration,
                );

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  color: Colors.white,
                  child: ExpansionTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    iconColor: Colors.orange.shade600,
                    collapsedIconColor: Colors.orange.shade400,
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child: Text('📅', style: const TextStyle(fontSize: 20)),
                    ),
                    title: Text(
                      'Adventures of $year',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    subtitle: Text(
                      '🌟 ${yearLogs.length} Events • ⏱️ $totalHours Hours',
                      style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    ),
                    childrenPadding: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
                    children: yearLogs.map((log) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.star_rounded, color: Colors.amber.shade400),
                            title: Text(
                              log.title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            subtitle: Text(
                              '${log.category}\n📍 ${log.venue} (${log.mode})',
                              style: TextStyle(color: Colors.grey.shade800),
                            ),
                            isThreeLine: true,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }
}