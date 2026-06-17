import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/performance_provider.dart';
import '../../models/performance_model.dart';
import 'start_review_screen.dart';

class TeacherRosterScreen extends StatefulWidget {
  const TeacherRosterScreen({super.key});

  @override
  State<TeacherRosterScreen> createState() => _TeacherRosterScreenState();
}

class _TeacherRosterScreenState extends State<TeacherRosterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PerformanceProvider>(
      builder: (context, provider, _) {
        final displayed = provider.searchTeachers(_searchQuery);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Teacher Performance'),
            // ← No more Add Teacher button here
            // Teachers are added via Module 1
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Teachers are managed in Module 1. '
                          'All active teachers appear here automatically.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    labelText: 'Search teacher name or NRIC',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),

                if (provider.teachers.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Showing ${displayed.length} of '
                      '${provider.teachers.length} teachers',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 8),

                Expanded(
                  child: provider.teachers.isEmpty
                      ? _buildEmptyState()
                      : displayed.isEmpty
                          ? const Center(
                              child: Text('No teacher found.'))
                          : ListView.builder(
                              itemCount: displayed.length,
                              itemBuilder: (context, index) {
                                final teacher = displayed[index];
                                return _TeacherCard(
                                  teacher: teacher,
                                  avgScore: provider
                                      .getAverageScore(teacher.id),
                                  evalCount: provider
                                      .getEvaluationCount(teacher.id),
                                  onEvaluate: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StartReviewScreen(
                                          teacher: teacher),
                                    ),
                                  ),
                                  // Delete only removes evaluations
                                  // not the teacher account
                                  onDelete: () => _confirmDeleteEvals(
                                      context, provider, teacher),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No active teachers found.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Add teachers in Module 1 first.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // Only deletes evaluations, NOT the teacher account
  void _confirmDeleteEvals(
    BuildContext context,
    PerformanceProvider provider,
    Teacher teacher,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete All Evaluations'),
        content: Text(
          'This will delete ALL evaluation records for '
          '${teacher.name}.\n\n'
          'The teacher account will NOT be affected. '
          'To remove a teacher, use Module 1.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () async {
              await provider.deleteTeacher(teacher.id);
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'All evaluations for ${teacher.name} deleted.'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('Delete Evaluations',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Teacher card ───────────────────────────────────────────────────────────────

class _TeacherCard extends StatelessWidget {
  final Teacher teacher;
  final double avgScore;
  final int evalCount;
  final VoidCallback onEvaluate;
  final VoidCallback onDelete;

  const _TeacherCard({
    required this.teacher,
    required this.avgScore,
    required this.evalCount,
    required this.onEvaluate,
    required this.onDelete,
  });

  Color get _gradeColor {
    if (avgScore >= 4.5) return Colors.green;
    if (avgScore >= 3.5) return Colors.lightGreen;
    if (avgScore >= 2.5) return Colors.orange;
    if (avgScore > 0) return Colors.red;
    return Colors.grey;
  }

  String get _gradeLabel {
    if (avgScore >= 4.5) return 'Excellent';
    if (avgScore >= 3.5) return 'Good';
    if (avgScore >= 2.5) return 'Satisfactory';
    if (avgScore > 0) return 'Needs Improvement';
    return 'Not Evaluated';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                teacher.getInitials(),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teacher.name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'NRIC: ${teacher.maskedNric}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$evalCount evaluation(s)',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _gradeColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      avgScore > 0
                          ? '${avgScore.toStringAsFixed(2)} • $_gradeLabel'
                          : _gradeLabel,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.assessment,
                      color: Colors.blue),
                  tooltip: 'Evaluate',
                  onPressed: onEvaluate,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep,
                      color: Colors.red),
                  tooltip: 'Delete Evaluations',
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}