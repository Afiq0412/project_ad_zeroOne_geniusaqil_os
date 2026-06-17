import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/report_model.dart';
import '../providers/report_provider.dart';
import 'submit_report_view.dart';
import 'report_card_widget.dart';

class ReportDashboardView extends StatelessWidget {
  const ReportDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().currentUserModel;
    final provider = context.read<ReportProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text('My Reports',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubmitReportView()),
        ),
        icon: const Icon(Icons.add),
        label: Text('New Report', style: GoogleFonts.inter()),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<ReportModel>>(
        stream: provider.streamMyReports(user?.id ?? ''),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load your reports. Please try again later.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.red.shade600,
                  ),
                ),
              ),
            );
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No reports submitted yet.',
                      style: GoogleFonts.inter(
                          fontSize: 16, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Text('Tap + to submit a new report.',
                      style: GoogleFonts.inter(color: Colors.grey.shade400)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) =>
                ReportCard(report: reports[index], isAdmin: false),
          );
        },
      ),
    );
  }
}

// ── Shared report card ─────────────────────────────────────────────────────────


