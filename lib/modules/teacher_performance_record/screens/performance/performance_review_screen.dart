import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/performance_provider.dart';
import '../../models/performance_model.dart';

class PerformanceReviewScreen extends StatelessWidget {
  final String categoryId;
  const PerformanceReviewScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    return Consumer<PerformanceProvider>(
      builder: (context, provider, _) {
        final record = provider.activeRecord;
        if (record == null) return const SizedBox.shrink();

        final category =
            record.categories.firstWhere((c) => c.id == categoryId);

        return Scaffold(
          appBar: AppBar(
            title: Text(category.title),
            actions: [
              if (category.isComplete)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.check_circle, color: Colors.greenAccent),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Score summary
              if (category.averageScore > 0)
                _CategoryScoreSummary(category: category),
              const SizedBox(height: 12),

              // Rating legend
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '1 = Poor  •  2 = Needs Improvement  •  3 = Satisfactory  •  4 = Good  •  5 = Excellent',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),

              // Criteria cards
              ...category.criteria.map(
                (criterion) => _CriterionRatingCard(
                  criterion: criterion,
                  onRatingChanged: (rating) => provider.updateRating(
                    categoryId: categoryId,
                    criterionId: criterion.id,
                    rating: rating,
                  ),
                  onRemarkChanged: (remark) => provider.updateRemark(
                    categoryId: categoryId,
                    criterionId: criterion.id,
                    remark: remark,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Done button
              if (category.isComplete)
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check),
                  label: const Text('Done — Back to Tracker'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Category average score banner ──────────────────────────────────────────────

class _CategoryScoreSummary extends StatelessWidget {
  final KpiCategory category;
  const _CategoryScoreSummary({required this.category});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Category Average: ', style: TextStyle(fontSize: 16)),
            Text(
              category.averageScore.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const Text(' / 5.0',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ── Single criterion rating card ───────────────────────────────────────────────

class _CriterionRatingCard extends StatefulWidget {
  final KpiCriterion criterion;
  final ValueChanged<int> onRatingChanged;
  final ValueChanged<String> onRemarkChanged;

  const _CriterionRatingCard({
    required this.criterion,
    required this.onRatingChanged,
    required this.onRemarkChanged,
  });

  @override
  State<_CriterionRatingCard> createState() => _CriterionRatingCardState();
}

class _CriterionRatingCardState extends State<_CriterionRatingCard> {
  bool _showRemark = false;
  late final TextEditingController _remarkController;

  @override
  void initState() {
    super.initState();
    _remarkController =
        TextEditingController(text: widget.criterion.remark ?? '');
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Color _starColor(int starIndex) {
    if (widget.criterion.rating >= starIndex) {
      if (widget.criterion.rating <= 2) return Colors.red;
      if (widget.criterion.rating == 3) return Colors.orange;
      return Colors.amber;
    }
    return Colors.grey.shade300;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: widget.criterion.rating > 0 ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: widget.criterion.rating > 0
              ? Colors.blue.shade200
              : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Criterion title
            Text(
              widget.criterion.title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),

            // Star rating row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                return GestureDetector(
                  onTap: () => widget.onRatingChanged(starValue),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.star_rounded,
                      size: 36,
                      color: _starColor(starValue),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),

            // Rating label
            if (widget.criterion.rating > 0)
              Center(
                child: Text(
                  RatingScale.values[widget.criterion.rating - 1].label,
                  style: TextStyle(
                    color:
                        RatingScale.values[widget.criterion.rating - 1].color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),

            // Remark toggle
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _showRemark = !_showRemark),
                icon: Icon(
                  _showRemark
                      ? Icons.expand_less
                      : Icons.comment_outlined,
                  size: 16,
                ),
                label: Text(
                  _showRemark ? 'Hide remark' : 'Add remark',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),

            // Remark text field
            if (_showRemark)
              TextField(
                controller: _remarkController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Optional remark or justification...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(10),
                ),
                onChanged: widget.onRemarkChanged,
              ),
          ],
        ),
      ),
    );
  }
}