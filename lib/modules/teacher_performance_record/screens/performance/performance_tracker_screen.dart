import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/performance_provider.dart';
import '../../models/performance_model.dart';
import 'performance_review_screen.dart';

class PerformanceTrackerScreen extends StatelessWidget {
  const PerformanceTrackerScreen({super.key});

  // Intercept back button and show warning
  Future<bool> _onWillPop(
      BuildContext context, PerformanceProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Discard Evaluation?'),
          ],
        ),
        content: const Text(
          'All ratings you have entered will not be saved.\n\n'
          'Are you sure you want to go back?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Evaluating'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Discard',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      provider.clearActiveRecord();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PerformanceProvider>(
      builder: (context, provider, _) {
        final record = provider.activeRecord;

        if (record == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Performance Tracker')),
            body: const Center(
              child: Text(
                  'No active review. Please start one from the teacher list.'),
            ),
          );
        }

        return PopScope(
          // false means we handle the pop ourselves
          canPop: false,
          onPopInvoked: (didPop) async {
            if (didPop) return;
            final shouldPop = await _onWillPop(context, provider);
            if (shouldPop && context.mounted) {
              Navigator.pop(context);
            }
          },
          child: Scaffold(
            appBar: AppBar(
              // Custom back button so it also triggers the warning
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  final shouldPop = await _onWillPop(context, provider);
                  if (shouldPop && context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Performance Tracker'),
                  Text(
                    '${record.teacherName} • ${record.reviewPeriod}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
              actions: [
                TextButton.icon(
                  onPressed: record.isComplete
                      ? () => _confirmSubmit(context, provider)
                      : null,
                  icon: const Icon(Icons.send, color: Colors.blue),
                  label: const Text(
                    'Submit',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                _buildOverallProgress(record),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: record.categories.length,
                    itemBuilder: (context, index) {
                      final category = record.categories[index];
                      return _KpiCategoryCard(
                        category: category,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PerformanceReviewScreen(
                              categoryId: category.id,
                            ),
                          ),
                        ),
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

  Widget _buildOverallProgress(TeacherPerformanceRecord record) {
    final completedCount =
        record.categories.where((c) => c.isComplete).length;
    final total = record.categories.length;
    final progress = completedCount / total;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress: $completedCount / $total categories',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (record.overallScore > 0)
                Chip(
                  label: Text(record.performanceGrade),
                  backgroundColor: Colors.blue.shade100,
                ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 6),
          Text(
            record.overallScore > 0
                ? 'Current Score: ${record.overallScore.toStringAsFixed(2)} / 5.00'
                : 'Complete all categories to see your score.',
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSubmit(
      BuildContext context, PerformanceProvider provider) async {
    final remarkController = TextEditingController(
        text: provider.activeRecord?.overallRemark ?? '');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Submit Review'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Add an overall remark before submitting (optional).'),
            const SizedBox(height: 12),
            TextField(
              controller: remarkController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Overall remark...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      provider.updateOverallRemark(remarkController.text);
      final success = await provider.submitReview();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Review submitted successfully!'
                : 'Please complete all ratings first.'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) Navigator.pop(context);
      }
    }
  }
}

// ── KPI category card ──────────────────────────────────────────────────────────

class _KpiCategoryCard extends StatelessWidget {
  final KpiCategory category;
  final VoidCallback onTap;

  const _KpiCategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final completedCriteria =
        category.criteria.where((c) => c.rating > 0).length;
    final total = category.criteria.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor:
              category.isComplete ? Colors.green : Colors.blue.shade100,
          child: Icon(
            category.isComplete ? Icons.check : category.icon,
            color: category.isComplete ? Colors.white : Colors.blue,
          ),
        ),
        title: Text(category.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('$completedCriteria / $total criteria rated'),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: completedCriteria / total,
              minHeight: 5,
              borderRadius: BorderRadius.circular(3),
              color: category.isComplete ? Colors.green : Colors.blue,
            ),
          ],
        ),
        trailing: category.averageScore > 0
            ? _ScoreBadge(score: category.averageScore)
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final double score;
  const _ScoreBadge({required this.score});

  Color get _color {
    if (score >= 4.5) return Colors.green;
    if (score >= 3.5) return Colors.lightGreen;
    if (score >= 2.5) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}