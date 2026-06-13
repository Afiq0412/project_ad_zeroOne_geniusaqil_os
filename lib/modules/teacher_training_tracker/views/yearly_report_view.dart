import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/training_model.dart';

class YearlyReportView extends StatelessWidget {
  final List<TrainingModel> logs;

  const YearlyReportView({super.key, required this.logs});

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
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          'Yearly Report',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: sortedYears.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_stories_rounded, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No history available.', style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 18)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedYears.length,
                  itemBuilder: (context, index) {
                    int year = sortedYears[index];
                    List<TrainingModel> yearLogs = groupedData[year]!;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: index == 0,
                          title: Text(
                            '$year Overview',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                          ),
                          subtitle: Text(
                            '${yearLogs.length} Activities Completed',
                            style: GoogleFonts.inter(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                          childrenPadding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                          children: yearLogs.map((log) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.star_rounded, color: Theme.of(context).colorScheme.primary),
                                  title: Text(
                                    log.title,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                  subtitle: Text(
                                    '${log.category}\n📍 ${log.venue} (${log.mode})',
                                    style: GoogleFonts.inter(color: Colors.grey.shade800),
                                  ),
                                  isThreeLine: true,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}