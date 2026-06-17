import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/performance_provider.dart';
import '../../models/performance_model.dart';

class PerformanceHistoryScreen extends StatelessWidget {
  final String teacherId;
  const PerformanceHistoryScreen({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context) {
    return Consumer<PerformanceProvider>(
      builder: (context, provider, _) {
        final records = provider.getRecordsByTeacher(teacherId);
        final teacherName =
            records.isNotEmpty ? records.first.teacherName : '';

        // Get unique years from all records, sorted descending
        final years = records
            .map((r) => r.evaluationDate.year)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

        return Scaffold(
          appBar: AppBar(title: Text('$teacherName — History')),
          body: records.isEmpty
              ? const Center(child: Text('No evaluations yet.'))
              : _YearTabView(
                  teacherId: teacherId,
                  teacherName: teacherName,
                  years: years,
                  records: records,
                  provider: provider,
                ),
        );
      },
    );
  }
}

// ── Year tab view ──────────────────────────────────────────────────────────────

class _YearTabView extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final List<int> years;
  final List<TeacherPerformanceRecord> records;
  final PerformanceProvider provider;

  const _YearTabView({
    required this.teacherId,
    required this.teacherName,
    required this.years,
    required this.records,
    required this.provider,
  });

  @override
  State<_YearTabView> createState() => _YearTabViewState();
}

class _YearTabViewState extends State<_YearTabView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.years.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Year tab bar
        Container(
          color: Colors.blue.shade50,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Colors.blue.shade700,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue.shade700,
            tabs: widget.years
                .map((year) => Tab(text: year.toString()))
                .toList(),
          ),
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: widget.years.map((year) {
              // Filter records for this year
              final yearRecords = widget.records
                  .where((r) => r.evaluationDate.year == year)
                  .toList();

              // Average for this year only
              final yearAvg = yearRecords.isEmpty
                  ? 0.0
                  : yearRecords
                          .map((r) => r.overallScore)
                          .reduce((a, b) => a + b) /
                      yearRecords.length;

              return _YearRecordList(
                year: year,
                records: yearRecords,
                yearAvg: yearAvg,
                provider: widget.provider,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Year record list ───────────────────────────────────────────────────────────

class _YearRecordList extends StatelessWidget {
  final int year;
  final List<TeacherPerformanceRecord> records;
  final double yearAvg;
  final PerformanceProvider provider;

  const _YearRecordList({
    required this.year,
    required this.records,
    required this.yearAvg,
    required this.provider,
  });

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  Color get _avgColor {
    if (yearAvg >= 4.5) return Colors.green;
    if (yearAvg >= 3.5) return Colors.lightGreen;
    if (yearAvg >= 2.5) return Colors.orange;
    if (yearAvg > 0) return Colors.red;
    return Colors.grey;
  }

  String get _avgGrade {
    if (yearAvg >= 4.5) return 'Excellent';
    if (yearAvg >= 3.5) return 'Good';
    if (yearAvg >= 2.5) return 'Satisfactory';
    if (yearAvg > 0) return 'Needs Improvement';
    return 'No Data';
  }

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No evaluations in $year.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Year summary banner
        Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Year label
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    year.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${records.length} evaluation(s)',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Year Average: ${yearAvg.toStringAsFixed(2)} / 5.00',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                // Grade chip
                Chip(
                  label: Text(
                    _avgGrade,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: _avgColor,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Records for this year
        ...records.map(
          (record) => _RecordCard(
            record: record,
            onDelete: () => _confirmDelete(context, record),
            onReview: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _ReviewDetailScreen(record: record),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TeacherPerformanceRecord record,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Evaluation'),
        content: Text(
          'Delete the evaluation for "${record.reviewPeriod}" '
          'dated ${_formatDate(record.evaluationDate)}?\n\n'
          'This will also update the average score.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      provider.deleteRecord(record.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evaluation deleted successfully.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ── Record card ────────────────────────────────────────────────────────────────

class _RecordCard extends StatelessWidget {
  final TeacherPerformanceRecord record;
  final VoidCallback onDelete;
  final VoidCallback onReview;

  const _RecordCard({
    required this.record,
    required this.onDelete,
    required this.onReview,
  });

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  Color get _gradeColor {
    switch (record.performanceGrade) {
      case 'Excellent': return Colors.green;
      case 'Good': return Colors.lightGreen;
      case 'Satisfactory': return Colors.orange;
      default: return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        title: Text(
          record.reviewPeriod,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Evaluated on ${_formatDate(record.evaluationDate)}  •  By ${record.reviewerName}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Chip(
          label: Text(
            record.performanceGrade,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          backgroundColor: _gradeColor,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                // Overall score
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Score: ',
                        style: TextStyle(fontSize: 16)),
                    Text(
                      '${record.overallScore.toStringAsFixed(2)} / 5.00',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _gradeColor,
                      ),
                    ),
                  ],
                ),
                const Divider(),

                // Per-category breakdown
                ...record.categories.map(
                  (cat) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(cat.icon, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(cat.title,
                              style: const TextStyle(fontSize: 13)),
                        ),
                        Text(
                          cat.averageScore.toStringAsFixed(1),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                // Overall remark
                if (record.overallRemark?.isNotEmpty == true) ...[
                  const Divider(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Remark: ${record.overallRemark}',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ),
                ],

                const Divider(),

                // Review + Delete buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReview,
                        icon: const Icon(Icons.visibility,
                            color: Colors.blue),
                        label: const Text('Review',
                            style: TextStyle(color: Colors.blue)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.blue),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete,
                            color: Colors.red),
                        label: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Review detail screen ───────────────────────────────────────────────────────

class _ReviewDetailScreen extends StatelessWidget {
  final TeacherPerformanceRecord record;
  const _ReviewDetailScreen({required this.record});

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  Color get _gradeColor {
    switch (record.performanceGrade) {
      case 'Excellent': return Colors.green;
      case 'Good': return Colors.lightGreen;
      case 'Satisfactory': return Colors.orange;
      default: return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('${record.teacherName} — ${record.reviewPeriod}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary card
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    record.teacherName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Period: ${record.reviewPeriod}  •  Date: ${_formatDate(record.evaluationDate)}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    record.overallScore.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: _gradeColor,
                    ),
                  ),
                  Text(
                    '/ 5.00  •  ${record.performanceGrade}',
                    style: TextStyle(color: _gradeColor),
                  ),
                  if (record.overallRemark?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Overall Remark: ${record.overallRemark}',
                        style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.blueGrey),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Each category
          ...record.categories.map(
            (category) => _CategoryReviewCard(category: category),
          ),
        ],
      ),
    );
  }
}

// ── Category review card ───────────────────────────────────────────────────────

class _CategoryReviewCard extends StatelessWidget {
  final KpiCategory category;
  const _CategoryReviewCard({required this.category});

  Color _scoreColor(double score) {
    if (score >= 4.5) return Colors.green;
    if (score >= 3.5) return Colors.lightGreen;
    if (score >= 2.5) return Colors.orange;
    return Colors.red;
  }

  Color _starColor(int rating, int starIndex) {
    if (rating >= starIndex) {
      if (rating <= 2) return Colors.red;
      if (rating == 3) return Colors.orange;
      return Colors.amber;
    }
    return Colors.grey.shade300;
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyRemark = category.criteria
        .any((c) => c.remark != null && c.remark!.isNotEmpty);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(category.icon, color: Colors.blue, size: 20),
        ),
        title: Text(
          category.title,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Row(
          children: [
            Text(
              'Avg: ${category.averageScore.toStringAsFixed(1)} / 5.0',
              style: TextStyle(
                color: _scoreColor(category.averageScore),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            if (hasAnyRemark) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Has Remarks',
                  style:
                      TextStyle(fontSize: 10, color: Colors.orange),
                ),
              ),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: category.criteria.map((criterion) {
                final hasRemark = criterion.remark != null &&
                    criterion.remark!.isNotEmpty;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasRemark
                        ? Colors.orange.shade50
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasRemark
                          ? Colors.orange.shade200
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        criterion.title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),

                      // Stars (read-only)
                      Row(
                        children: [
                          Row(
                            children: List.generate(5, (i) {
                              return Icon(
                                Icons.star_rounded,
                                size: 24,
                                color: _starColor(
                                    criterion.rating, i + 1),
                              );
                            }),
                          ),
                          const SizedBox(width: 8),
                          if (criterion.rating > 0)
                            Text(
                              RatingScale
                                  .values[criterion.rating - 1].label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: RatingScale
                                    .values[criterion.rating - 1]
                                    .color,
                              ),
                            ),
                        ],
                      ),

                      // Remark — only shown if exists
                      if (hasRemark) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.orange.shade300),
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.comment,
                                  size: 14, color: Colors.orange),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  criterion.remark!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}