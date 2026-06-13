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
    final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel!;
    final bool isPrincipal = user.role.toLowerCase() == 'principal' || user.role.toLowerCase() == 'admin';
    final trainingProvider = Provider.of<TrainingProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          isPrincipal ? 'Principal Dashboard' : 'My Learning Journey',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_mosaic_rounded, size: 24),
            tooltip: 'Yearly Summary',
            onPressed: () => Navigator.push(
              context,
              // Ideally you would pass actual logs here rather than an empty array if you pre-fetch them.
              MaterialPageRoute(builder: (_) => const YearlyReportView(logs: [])), 
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: StreamBuilder<List<TrainingModel>>(
            stream: isPrincipal 
                ? trainingProvider.streamAllTrainings() 
                : trainingProvider.streamTeacherTrainings(user.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Failed to load activities.\n${snapshot.error}',
                    style: GoogleFonts.inter(color: Colors.red.shade400),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              List<TrainingModel> items = snapshot.data ?? [];
              
              if (items.isEmpty) {
                 return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 80, color: Colors.green.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('No training logs yet.', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final log = items[index];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        log.title,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Category: ${log.category}\nDate: ${DateFormat('MMM d, yyyy').format(log.date)}',
                            style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                            onPressed: () => _confirmDelete(context, trainingProvider, log),
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: !isPrincipal
          ? FloatingActionButton.extended(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text('Add Activity', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrainingFormView()),
              ),
            )
          : null,
    );
  }

  void _confirmDelete(BuildContext context, TrainingProvider provider, TrainingModel log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Log?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${log.title}"? This cannot be undone.', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
            onPressed: () async {
              Navigator.pop(ctx); 
              if (log.id != null) {
                bool success = await provider.deleteTraining(log.id!);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Log deleted successfully', style: GoogleFonts.inter())),
                  );
                }
              }
            },
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}