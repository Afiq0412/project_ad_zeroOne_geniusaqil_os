import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/training_provider.dart';
import '../models/training_model.dart';
import 'training_form_view.dart';
import 'yearly_report_view.dart';

class TrainingDashboardView extends StatelessWidget {
  const TrainingDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final user =
        Provider.of<AuthProvider>(context, listen: false).currentUserModel!;
    final bool isPrincipal = user.role.toLowerCase() == 'principal' ||
        user.role.toLowerCase() == 'admin';
    final trainingProvider =
        Provider.of<TrainingProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          isPrincipal ? 'Principal Dashboard' : 'Learning Journey',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_mosaic),
            tooltip: 'Yearly Report',
            onPressed: () {
              // Fetch logs for yearly report
              final logs = isPrincipal
                  ? trainingProvider.streamAllTrainings()
                  : trainingProvider.streamTeacherTrainings(user.id);

              logs.first.then((data) {
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => YearlyReportView(logs: data),
                    ),
                  );
                }
              });
            },
          ),
        ],
      ),
      body: StreamBuilder<List<TrainingModel>>(
        stream: isPrincipal
            ? trainingProvider.streamAllTrainings()
            : trainingProvider.streamTeacherTrainings(user.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading data: ${snapshot.error}',
                  style: GoogleFonts.inter(color: Colors.red)),
            );
          }
          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_edu,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No training records found.',
                    style: GoogleFonts.inter(
                        fontSize: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    log.title,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '📅 ${DateFormat('dd MMM yyyy').format(log.date)}'),
                        const SizedBox(height: 4),
                        Text('🏢 ${log.organizer}'),
                        const SizedBox(height: 4),
                        Text('📍 ${log.venue} (${log.mode})'),
                      ],
                    ),
                  ),
                  trailing: isPrincipal
                      ? const Icon(Icons.visibility,
                          color: Colors.blue) // Principal sees view icon
                      : IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () =>
                              _confirmDelete(context, trainingProvider, log),
                        ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TrainingFormView(
                          logToEdit: log,
                          isViewOnly:
                              isPrincipal, // 👈 Principal flag applied here
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      // 👈 Hide the floating action button if it's the principal
      floatingActionButton: isPrincipal
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const TrainingFormView(isViewOnly: false),
                  ),
                );
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('Add Log',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
    );
  }

  void _confirmDelete(
      BuildContext context, TrainingProvider provider, TrainingModel log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Log?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure you want to delete "${log.title}"? This cannot be undone.',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
            onPressed: () async {
              Navigator.pop(ctx);
              if (log.id != null) {
                bool success = await provider.deleteTraining(log.id!);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Log deleted successfully',
                            style: GoogleFonts.inter())),
                  );
                }
              }
            },
            child:
                Text('Delete', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
