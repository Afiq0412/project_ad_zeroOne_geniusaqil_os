import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/duty_constants.dart';
import '../providers/duty_provider.dart';

class DutyPerformanceView extends StatefulWidget {
  const DutyPerformanceView({super.key});

  @override
  State<DutyPerformanceView> createState() => _DutyPerformanceViewState();
}

class _DutyPerformanceViewState extends State<DutyPerformanceView> {
  late int _selectedYear;
  late int _selectedMonth;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedYear == now.year && _selectedMonth == now.month;
  }

  void _previousMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
    });
  }

  void _nextMonth() {
    if (_isCurrentMonth) return;
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
    });
  }

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  int _daysPassed(int year, int month) {
    final now = DateTime.now();
    if (year < now.year || (year == now.year && month < now.month)) {
      return _daysInMonth(year, month);
    } else if (year == now.year && month == now.month) {
      return now.day;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final provider = Provider.of<DutyProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          'Monthly Performance',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Month Navigation Card ─────────────────────────────
          _MonthHeaderCard(
            selectedYear: _selectedYear,
            selectedMonth: _selectedMonth,
            monthNames: _monthNames,
            isCurrentMonth: _isCurrentMonth,
            daysPassed: _daysPassed(_selectedYear, _selectedMonth),
            daysInMonth: _daysInMonth(_selectedYear, _selectedMonth),
            primary: primary,
            onPrevious: _previousMonth,
            onNext: _nextMonth,
          ),

          // ── FutureBuilder Body ────────────────────────────────
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              key: ValueKey('$_selectedYear-$_selectedMonth'),
              future: provider.getMonthlyPerformance(_selectedYear, _selectedMonth),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: const [
                      SizedBox(height: 16),
                      _ShimmerPlaceholder(),
                      _ShimmerPlaceholder(),
                      _ShimmerPlaceholder(),
                    ],
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load performance data',
                            style: GoogleFonts.outfit(
                              fontSize: 16, fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F2937),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final data = snapshot.data ?? [];
                if (data.isEmpty || data.every((t) => (t['totalAssigned'] as int) == 0)) {
                  return _EmptyState(
                    monthName: _monthNames[_selectedMonth - 1],
                    year: _selectedYear,
                  );
                }

                return _PerformanceBody(data: data, primary: primary);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month Header Card
// ─────────────────────────────────────────────────────────────────────────────
class _MonthHeaderCard extends StatelessWidget {
  final int selectedYear;
  final int selectedMonth;
  final List<String> monthNames;
  final bool isCurrentMonth;
  final int daysPassed;
  final int daysInMonth;
  final Color primary;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthHeaderCard({
    required this.selectedYear,
    required this.selectedMonth,
    required this.monthNames,
    required this.isCurrentMonth,
    required this.daysPassed,
    required this.daysInMonth,
    required this.primary,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final progress = daysInMonth > 0 ? daysPassed / daysInMonth : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Card(
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            children: [
              // Nav row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavButton(onTap: onPrevious, icon: Icons.chevron_left, enabled: true),
                  Column(
                    children: [
                      Text(
                        monthNames[selectedMonth - 1],
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      Text(
                        '$selectedYear',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  _NavButton(onTap: onNext, icon: Icons.chevron_right, enabled: !isCurrentMonth),
                ],
              ),

              if (isCurrentMonth) ...[
                const SizedBox(height: 14),
                Text(
                  'Month in progress • $daysPassed of $daysInMonth days',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Month completed — final results',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final bool enabled;

  const _NavButton({required this.onTap, required this.icon, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: enabled ? Colors.grey.shade100 : Colors.grey.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.grey.shade700 : Colors.grey.shade300,
          size: 22,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Performance Body
// ─────────────────────────────────────────────────────────────────────────────
class _PerformanceBody extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final Color primary;

  const _PerformanceBody({required this.data, required this.primary});

  @override
  State<_PerformanceBody> createState() => _PerformanceBodyState();
}

class _PerformanceBodyState extends State<_PerformanceBody> {
  String _sortBy = 'By Rate';

  bool get _allZeroPercent =>
      widget.data.every((t) => (t['completionRate'] as double) == 0.0);

  bool get _anyHasCompletion =>
      widget.data.any((t) => (t['completionRate'] as double) > 0.0);

  @override
  Widget build(BuildContext context) {
    // Sort logic
    final sortedData = List<Map<String, dynamic>>.from(widget.data);
    if (_sortBy == 'By Rate') {
      if (_allZeroPercent) {
        // All 0% → sort by assigned count descending
        sortedData.sort((a, b) => (b['totalAssigned'] as int).compareTo(a['totalAssigned'] as int));
      } else {
        sortedData.sort((a, b) => (b['completionRate'] as double).compareTo(a['completionRate'] as double));
      }
    } else if (_sortBy == 'By Name') {
      sortedData.sort((a, b) => (a['teacherName'] as String).compareTo(b['teacherName'] as String));
    } else if (_sortBy == 'By Missed') {
      sortedData.sort((a, b) => (b['missed'] as int).compareTo(a['missed'] as int));
    }

    final int totalAssigned = widget.data.fold(0, (sum, t) => sum + (t['totalAssigned'] as int));
    final int totalCompleted = widget.data.fold(0, (sum, t) => sum + (t['completed'] as int));
    final int totalMissed = widget.data.fold(0, (sum, t) => sum + (t['missed'] as int));
    final int totalUpcoming = widget.data.fold(0, (sum, t) => sum + (t['upcoming'] as int));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // ── Stats 2x2 Grid ────────────────────────────────────
        _buildStatsGrid(totalAssigned, totalCompleted, totalMissed, totalUpcoming),

        const SizedBox(height: 12),

        // ── Info Banner ───────────────────────────────────────
        _buildInfoBanner(),

        const SizedBox(height: 12),

        // ── Podium or empty podium message ────────────────────
        if (_anyHasCompletion && widget.data.length >= 3)
          _buildPodiumBanner(widget.data, widget.primary)
        else
          _buildEmptyPodiumMessage(),

        const SizedBox(height: 4),

        // ── Sorting chips ─────────────────────────────────────
        _buildSortingChips(),

        // ── Teacher Cards ─────────────────────────────────────
        ...sortedData.map((t) => _TeacherPerformanceCard(
              teacher: t,
              primary: widget.primary,
            )),
      ],
    );
  }

  Widget _buildStatsGrid(int assigned, int completed, int missed, int upcoming) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatGridCard(
                title: 'Total Assigned',
                value: '$assigned',
                icon: Icons.assignment_outlined,
                iconColor: const Color(0xFF1565C0),
                bgColor: const Color(0xFFE3F0FF),
                borderColor: const Color(0xFFBBD6FB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatGridCard(
                title: 'Completed',
                value: '$completed',
                icon: Icons.check_circle_outline_rounded,
                iconColor: const Color(0xFF2E7D32),
                bgColor: const Color(0xFFE6F4EA),
                borderColor: const Color(0xFFA8D5B0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatGridCard(
                title: 'Missed',
                value: '$missed',
                icon: Icons.cancel_outlined,
                iconColor: const Color(0xFFC62828),
                bgColor: const Color(0xFFFFEBEE),
                borderColor: const Color(0xFFFFCDD2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatGridCard(
                title: 'Upcoming',
                value: '$upcoming',
                icon: Icons.watch_later_outlined,
                iconColor: const Color(0xFF616161),
                bgColor: const Color(0xFFF5F5F5),
                borderColor: const Color(0xFFE0E0E0),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDE7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDD835).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Performance updates as teachers complete their duties',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF5D4037),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPodiumMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFCC02).withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text(
            'No completions yet this month',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Podium will appear once teachers start marking duties done',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF795548),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumBanner(List<Map<String, dynamic>> teachersData, Color primary) {
    final sorted = List<Map<String, dynamic>>.from(teachersData)
      ..sort((a, b) => (b['completionRate'] as double).compareTo(a['completionRate'] as double));

    final first = sorted[0];
    final second = sorted[1];
    final third = sorted[2];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            primary.withOpacity(0.08),
            const Color(0xFFFAF9FF),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: primary.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '🏆 Top Performers This Month',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 20),
          // Podium visual layout — aligned at bottom
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd Place — left, medium height
              Expanded(
                child: _PodiumSlot(
                  teacher: second,
                  rankEmoji: '🥈',
                  avatarRadius: 26,
                  podiumHeight: 56,
                  podiumColor: const Color(0xFFB0BEC5),
                  rankLabel: '2nd',
                  isFirst: false,
                ),
              ),
              const SizedBox(width: 8),
              // 1st Place — center, tallest
              Expanded(
                child: _PodiumSlot(
                  teacher: first,
                  rankEmoji: '🥇',
                  avatarRadius: 34,
                  podiumHeight: 80,
                  podiumColor: const Color(0xFFFFD54F),
                  rankLabel: '1st',
                  isFirst: true,
                ),
              ),
              const SizedBox(width: 8),
              // 3rd Place — right, shortest
              Expanded(
                child: _PodiumSlot(
                  teacher: third,
                  rankEmoji: '🥉',
                  avatarRadius: 22,
                  podiumHeight: 42,
                  podiumColor: const Color(0xFFBCAAA4),
                  rankLabel: '3rd',
                  isFirst: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortingChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            'Sort:',
            style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(width: 8),
          _buildChip('By Rate'),
          const SizedBox(width: 6),
          _buildChip('By Name'),
          const SizedBox(width: 6),
          _buildChip('By Missed'),
        ],
      ),
    );
  }

  Widget _buildChip(String sortBy) {
    final isSelected = _sortBy == sortBy;
    final primary = widget.primary;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = sortBy),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? primary : Colors.grey.shade300),
          boxShadow: isSelected
              ? [BoxShadow(color: primary.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          sortBy,
          style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat Grid Card (2x2)
// ─────────────────────────────────────────────────────────────────────────────
class _StatGridCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;

  const _StatGridCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF111827),
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Podium Slot
// ─────────────────────────────────────────────────────────────────────────────
class _PodiumSlot extends StatelessWidget {
  final Map<String, dynamic> teacher;
  final String rankEmoji;
  final double avatarRadius;
  final double podiumHeight;
  final Color podiumColor;
  final String rankLabel;
  final bool isFirst;

  const _PodiumSlot({
    required this.teacher,
    required this.rankEmoji,
    required this.avatarRadius,
    required this.podiumHeight,
    required this.podiumColor,
    required this.rankLabel,
    required this.isFirst,
  });

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.substring(0, math.min(2, name.length)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final name = teacher['teacherName'] as String;
    final rate = teacher['completionRate'] as double;
    final gradeColor = Color(teacher['gradeColor'] as int);
    final initials = _getInitials(name);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(rankEmoji, style: TextStyle(fontSize: isFirst ? 32 : 24)),
        const SizedBox(height: 6),
        // Avatar with ring
        Container(
          width: avatarRadius * 2 + 6,
          height: avatarRadius * 2 + 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: gradeColor.withOpacity(0.15),
            border: Border.all(color: gradeColor, width: 2.5),
          ),
          child: Center(
            child: Text(
              initials,
              style: GoogleFonts.outfit(
                color: gradeColor,
                fontWeight: FontWeight.bold,
                fontSize: isFirst ? 18 : 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: GoogleFonts.outfit(
            fontSize: isFirst ? 13 : 11,
            fontWeight: isFirst ? FontWeight.bold : FontWeight.w600,
            color: const Color(0xFF1F2937),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          '${rate.toStringAsFixed(0)}%',
          style: GoogleFonts.inter(
            fontSize: isFirst ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: gradeColor,
          ),
        ),
        const SizedBox(height: 6),
        // Podium block
        Container(
          height: podiumHeight,
          decoration: BoxDecoration(
            color: podiumColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Center(
            child: Text(
              rankLabel,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Teacher Performance Card (ExpansionTile with left border strip)
// ─────────────────────────────────────────────────────────────────────────────
class _TeacherPerformanceCard extends StatelessWidget {
  final Map<String, dynamic> teacher;
  final Color primary;

  const _TeacherPerformanceCard({required this.teacher, required this.primary});

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.substring(0, math.min(2, name.length)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final name = teacher['teacherName'] as String;
    final grade = teacher['grade'] as String;
    final gradeColor = Color(teacher['gradeColor'] as int);
    final rate = (teacher['completionRate'] as double).clamp(0.0, 100.0);
    final completed = teacher['completed'] as int;
    final missed = teacher['missed'] as int;
    final upcoming = teacher['upcoming'] as int;
    final totalAssigned = teacher['totalAssigned'] as int;
    final dutyBreakdown = (teacher['dutyBreakdown'] as Map<String, dynamic>?) ?? {};

    String gradeEmoji = '🌟';
    if (grade == 'Good') gradeEmoji = '👍';
    else if (grade == 'Fair') gradeEmoji = '📈';
    else if (grade == 'Needs Attention') gradeEmoji = '⚠️';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left border color strip
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: gradeColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
            ),
            // Card content
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  childrenPadding: EdgeInsets.zero,
                  iconColor: gradeColor,
                  collapsedIconColor: Colors.grey.shade400,
                  title: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Ring with % and initials
                      _PercentageRing(
                        rate: rate,
                        initials: _getInitials(name),
                        gradeColor: gradeColor,
                        grade: grade,
                      ),
                      const SizedBox(width: 14),
                      // Right info column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: const Color(0xFF111827),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            // Grade chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: gradeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$gradeEmoji $grade',
                                style: GoogleFonts.inter(
                                  fontSize: 11, fontWeight: FontWeight.bold,
                                  color: gradeColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Mini stats row
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _MiniStatChip(icon: '📋', label: '$totalAssigned assigned', color: Colors.blueGrey),
                                _MiniStatChip(icon: '❌', label: '$missed missed', color: Colors.red.shade700),
                                _MiniStatChip(icon: '⏳', label: '$upcoming upcoming', color: Colors.grey.shade600),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  children: [
                    // Expanded breakdown
                    Container(
                      color: const Color(0xFFFAFAFA),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 1, color: Color(0xFFEEEEEE)),
                            const SizedBox(height: 12),
                            // Mini stat pills row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _StatPill('✅', '$completed', Colors.green.shade50, Colors.green.shade800),
                                _StatPill('❌', '$missed', Colors.red.shade50, Colors.red.shade800),
                                _StatPill('⏳', '$upcoming', Colors.grey.shade100, Colors.grey.shade700),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Duty Type Breakdown',
                              style: GoogleFonts.inter(
                                fontSize: 11, fontWeight: FontWeight.bold,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Duty bars
                            ...DutyConstants.allDutyTypes.map((type) {
                              final breakdown = dutyBreakdown[type] as Map<String, dynamic>?;
                              if (breakdown == null || (breakdown['assigned'] ?? 0) == 0) {
                                return const SizedBox.shrink();
                              }
                              final assigned = breakdown['assigned'] as int;
                              final completedVal = breakdown['completed'] as int;
                              final typeRate = assigned == 0 ? 0.0 : (completedVal / assigned);
                              final barColor = typeRate == 0 ? Colors.red.shade300 : Colors.green.shade500;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(DutyConstants.icon(type), style: const TextStyle(fontSize: 13)),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            DutyConstants.displayName(type),
                                            style: GoogleFonts.inter(
                                              fontSize: 11, fontWeight: FontWeight.w600,
                                              color: const Color(0xFF374151),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '$completedVal / $assigned',
                                          style: GoogleFonts.inter(
                                            fontSize: 11, fontWeight: FontWeight.bold,
                                            color: typeRate == 0
                                                ? Colors.red.shade600
                                                : Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: typeRate,
                                        minHeight: 6,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Percentage Ring widget
// ─────────────────────────────────────────────────────────────────────────────
class _PercentageRing extends StatelessWidget {
  final double rate;
  final String initials;
  final Color gradeColor;
  final String grade;

  const _PercentageRing({
    required this.rate,
    required this.initials,
    required this.gradeColor,
    required this.grade,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gradeColor.withOpacity(0.07),
            ),
          ),
          // Progress ring
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              value: rate / 100,
              strokeWidth: 7,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
              strokeCap: StrokeCap.round,
            ),
          ),
          // Center content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${rate.toStringAsFixed(0)}%',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111827),
                ),
              ),
              Text(
                grade == 'Needs Attention' ? 'Attn.' : grade,
                style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w600,
                  color: gradeColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini stat chip (inline, text-only)
// ─────────────────────────────────────────────────────────────────────────────
class _MiniStatChip extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;

  const _MiniStatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat pill (in expanded section)
// ─────────────────────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String emoji;
  final String count;
  final Color bgColor;
  final Color textColor;

  const _StatPill(this.emoji, this.count, this.bgColor, this.textColor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            count,
            style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer Loading Placeholder
// ─────────────────────────────────────────────────────────────────────────────
class _ShimmerPlaceholder extends StatefulWidget {
  const _ShimmerPlaceholder();

  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: 0.3 + (_controller.value * 0.4),
        child: child,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200, shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 140, height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80, height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 180, height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State (no duty records for the month)
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String monthName;
  final int year;

  const _EmptyState({required this.monthName, required this.year});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            Text(
              'No duty records yet for $monthName $year',
              style: GoogleFonts.outfit(
                fontSize: 18, fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Performance data appears once the weekly roster is published and duties begin',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
