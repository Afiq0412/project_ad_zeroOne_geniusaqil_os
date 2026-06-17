import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/duty_constants.dart';
import '../providers/duty_provider.dart';
import '../../auth/models/user_model.dart';

class DutyAssignmentPicker extends StatefulWidget {
  final String day;
  final String zone;
  final String dutyType;
  final DateTime weekStart;
  final List<String> currentAssignments;

  const DutyAssignmentPicker({
    super.key,
    required this.day,
    required this.zone,
    required this.dutyType,
    required this.weekStart,
    required this.currentAssignments,
  });

  @override
  State<DutyAssignmentPicker> createState() => _DutyAssignmentPickerState();
}

class _DutyAssignmentPickerState extends State<DutyAssignmentPicker> {
  final TextEditingController _themeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _availableTeachers = [];
  List<UserModel> _filteredTeachers = [];
  List<String> _selectedTeacherIds = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedTeacherIds = List<String>.from(widget.currentAssignments);
    if (widget.zone == DutyConstants.assemblySubThemeKey) {
      _themeController.text =
          widget.currentAssignments.isNotEmpty ? widget.currentAssignments.first : '';
      _isLoading = false;
    } else {
      _loadTeachers();
    }
  }

  @override
  void dispose() {
    _themeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int _dayOffset(String dayName) {
    switch (dayName) {
      case 'Monday': return 0;
      case 'Tuesday': return 1;
      case 'Wednesday': return 2;
      case 'Thursday': return 3;
      case 'Friday': return 4;
      default: return 0;
    }
  }

  Future<void> _loadTeachers() async {
    try {
      final provider = Provider.of<DutyProvider>(context, listen: false);
      final allTeachers = await provider.getAllTeachers();

      final targetDate = widget.weekStart.add(Duration(days: _dayOffset(widget.day)));
      final leaves = await provider.getApprovedLeavesForDate(targetDate);
      final onLeaveUserIds = leaves.map((l) => l['teacherId'] as String).toSet();

      // Filter out teachers who are on approved leave
      setState(() {
        _availableTeachers = allTeachers.where((t) => !onLeaveUserIds.contains(t.id)).toList();
        _filteredTeachers = List.from(_availableTeachers);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading teachers for picker: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterTeachers(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredTeachers = List.from(_availableTeachers);
      } else {
        _filteredTeachers = _availableTeachers
            .where((t) => t.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _saveTheme() async {
    final provider = Provider.of<DutyProvider>(context, listen: false);
    final success = await provider.assignTeacher(
      widget.day,
      widget.zone,
      _themeController.text.trim(),
    );

    if (mounted) {
      _showSnackbar(
        success ? 'Assembly Sub Theme updated successfully' : 'Failed to update Assembly Sub Theme',
        success ? Colors.green.shade700 : Colors.red.shade700,
      );
      Navigator.pop(context);
    }
  }

  Future<void> _saveAssignments() async {
    final provider = Provider.of<DutyProvider>(context, listen: false);
    final success = await provider.assignTeachersList(
      widget.day,
      widget.zone,
      _selectedTeacherIds,
    );

    if (mounted) {
      _showSnackbar(
        success ? 'Assignments saved successfully' : 'Failed to save assignments',
        success ? Colors.green.shade700 : Colors.red.shade700,
      );
      Navigator.pop(context);
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final isThemeKey = widget.zone == DutyConstants.assemblySubThemeKey;
    final maxTeachers = DutyConstants.getMaxTeachers(widget.zone);
    final isMultiSelect = maxTeachers > 1;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handlebar for bottom sheet
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isThemeKey ? 'Edit Assembly Sub Theme' : 'Assign Teacher',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DutyConstants.displayName(widget.dutyType)} · ${widget.zone} (${widget.day})',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                  ),
                )
              ],
            ),
            const Divider(height: 24),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (isThemeKey) ...[
              // Text Field for Assembly Sub Theme
              Text(
                'Sub Theme Text',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _themeController,
                style: GoogleFonts.inter(),
                decoration: InputDecoration(
                  hintText: 'Enter the week\'s assembly theme...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveTheme,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Save Theme',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ] else ...[
              // Teacher Selection List
              // Search input
              TextField(
                controller: _searchController,
                onChanged: _filterTeachers,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search teachers...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _filterTeachers('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              if (isMultiSelect)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select up to $maxTeachers teachers:',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '${_selectedTeacherIds.length} / $maxTeachers selected',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _selectedTeacherIds.length > maxTeachers ? Colors.red : primary,
                        ),
                      ),
                    ],
                  ),
                ),

              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: _filteredTeachers.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.people_outline, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No teachers available'
                                  : 'No teachers match "$_searchQuery"',
                              style: GoogleFonts.inter(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredTeachers.length,
                        itemBuilder: (context, index) {
                          final teacher = _filteredTeachers[index];
                          final isSelected = _selectedTeacherIds.contains(teacher.id);

                          // Initials
                          final nameParts = teacher.name.trim().split(' ').where((p) => p.isNotEmpty).toList();
                          final initials = nameParts.length >= 2
                              ? '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase()
                              : teacher.name.isNotEmpty
                                  ? teacher.name[0].toUpperCase()
                                  : '?';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? primary.withValues(alpha: 0.05) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? primary.withValues(alpha: 0.3) : Colors.grey.shade200,
                              ),
                            ),
                            child: ListTile(
                              onTap: () {
                                if (isMultiSelect) {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedTeacherIds.remove(teacher.id);
                                    } else {
                                      if (_selectedTeacherIds.length < maxTeachers) {
                                        _selectedTeacherIds.add(teacher.id);
                                      } else {
                                        _showSnackbar(
                                          'Maximum of $maxTeachers teachers can be assigned to this zone',
                                          Colors.orange.shade700,
                                        );
                                      }
                                    }
                                  });
                                } else {
                                  setState(() {
                                    _selectedTeacherIds = [teacher.id];
                                  });
                                  _saveAssignments();
                                }
                              },
                              leading: CircleAvatar(
                                backgroundColor: isSelected ? primary : Colors.grey.shade100,
                                foregroundColor: isSelected ? Colors.white : primary,
                                child: Text(initials, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                              ),
                              title: Text(
                                teacher.name,
                                style: GoogleFonts.inter(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                              subtitle: Text(
                                teacher.email,
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                              ),
                              trailing: isMultiSelect
                                  ? Checkbox(
                                      value: isSelected,
                                      activeColor: primary,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            if (_selectedTeacherIds.length < maxTeachers) {
                                              _selectedTeacherIds.add(teacher.id);
                                            } else {
                                              _showSnackbar(
                                                'Maximum of $maxTeachers teachers can be assigned to this zone',
                                                Colors.orange.shade700,
                                              );
                                            }
                                          } else {
                                            _selectedTeacherIds.remove(teacher.id);
                                          }
                                        });
                                      },
                                    )
                                  : (isSelected ? Icon(Icons.check_circle, color: primary) : null),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  if (!isMultiSelect)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedTeacherIds = [];
                          });
                          _saveAssignments();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.red.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Unassign / Clear Slot',
                          style: GoogleFonts.inter(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (isMultiSelect) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedTeacherIds = [];
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Clear All',
                          style: GoogleFonts.inter(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveAssignments,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Save Assignments',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
