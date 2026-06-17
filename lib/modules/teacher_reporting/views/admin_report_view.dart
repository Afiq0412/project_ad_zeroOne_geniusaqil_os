import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/report_model.dart';
import '../providers/report_provider.dart';
import 'report_card_widget.dart';

class AdminReportsView extends StatefulWidget {
  const AdminReportsView({super.key});

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> {
  String _filterStatus = 'All';
  final List<String> _statuses = ['All', 'Pending', 'In Review', 'Resolved'];

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ReportProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text('All Reports',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: StreamBuilder<List<ReportModel>>(
        stream: provider.streamAllReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data ?? [];
          final filtered = _filterStatus == 'All'
              ? all
              : all.where((r) => r.status == _filterStatus).toList();

          // Count per status for badges
          final pending = all.where((r) => r.status == 'Pending').length;
          final inReview = all.where((r) => r.status == 'In Review').length;
          final resolved = all.where((r) => r.status == 'Resolved').length;

          return Column(
            children: [
              // Summary banner
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _summaryChip('Total', all.length, Colors.blue),
                    _summaryChip('Pending', pending, Colors.orange),
                    _summaryChip('In Review', inReview, Colors.purple),
                    _summaryChip('Resolved', resolved, Colors.green),
                  ],
                ),
              ),

              // Filter tabs
              Container(
                color: Colors.white,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: _statuses.map((s) {
                      final selected = _filterStatus == s;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(s,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: selected
                                      ? Colors.white
                                      : Colors.grey.shade700)),
                          selected: selected,
                          onSelected: (_) => setState(() => _filterStatus = s),
                          selectedColor: Theme.of(context).colorScheme.primary,
                          backgroundColor: Colors.grey.shade100,
                          showCheckmark: false,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Report list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No $_filterStatus reports.',
                          style: GoogleFonts.inter(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => ReportCard(
                          report: filtered[index],
                          isAdmin: true,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label,
            style:
                GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}
