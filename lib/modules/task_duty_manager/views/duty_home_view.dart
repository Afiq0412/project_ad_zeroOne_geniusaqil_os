import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../constants/duty_constants.dart';

/// Phase 1 entry view for the Task & Duty Manager module.
///
/// Shows a role-aware overview of all 5 duty types with their zones
/// and time slots. Full schedule editing and checklist tracking will
/// be added in Phase 2 and Phase 3 respectively.
class DutyHomeView extends StatelessWidget {
  const DutyHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel;
    final isPrincipal = user?.role.toLowerCase() == 'principal';
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          'Task & Duty Manager',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Header ────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPrincipal ? Icons.admin_panel_settings_outlined : Icons.person_outlined,
                          size: 16,
                          color: primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isPrincipal ? 'Principal View' : 'Teacher View',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: primary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Text(
                'Duty Schedule Overview',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'All 5 duty types and their zones at a glance.',
                style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 14),
              ),

              const SizedBox(height: 20),

              // ── Duty type cards ────────────────────────────────
              ...DutyConstants.allDutyTypes
                  .map((type) => _DutyTypeCard(dutyType: type)),

              const SizedBox(height: 12),

              // ── Phase notice banner ───────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDE7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.rocket_launch_outlined,
                        color: Colors.amber, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'More Features Coming',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPrincipal
                                ? 'Schedule editor, auto-assign, and the full '
                                    'principal roster dashboard are coming in '
                                    'Phase 2.'
                                : 'Your daily duty assignments and checklist '
                                    'tracker are coming in Phase 3.',
                            style: GoogleFonts.inter(
                                color: Colors.grey.shade700, fontSize: 13),
                          ),
                        ],
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

// ── Private duty card widget ─────────────────────────────────────────────────

class _DutyTypeCard extends StatelessWidget {
  final String dutyType;
  const _DutyTypeCard({required this.dutyType});

  @override
  Widget build(BuildContext context) {
    final name = DutyConstants.displayName(dutyType);
    final icon = DutyConstants.icon(dutyType);
    final time = DutyConstants.timeSlot(dutyType);
    final freq = DutyConstants.frequency[dutyType] ?? '';
    final zones = DutyConstants.zonesFor(dutyType);
    final accentColor = Color(DutyConstants.dutyColors[dutyType] ?? 0xFF1E5480);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card header ──────────────────────────────────
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$time  ·  $freq',
                              style: GoogleFonts.inter(
                                  color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Zone chips ───────────────────────────────────
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: zones
                  .map((z) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: accentColor.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          z,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: accentColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ))
                  .toList(),
            ),

            // ── Checklist indicator for Cleaning Duty ────────
            if (dutyType == DutyConstants.cleaning) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.checklist_rounded,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Has detailed zone checklists',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
