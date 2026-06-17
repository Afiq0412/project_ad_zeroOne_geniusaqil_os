import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../providers/manage_users_provider.dart';

class ManageUsersView extends StatefulWidget {
  const ManageUsersView({super.key});

  @override
  State<ManageUsersView> createState() => _ManageUsersViewState();
}

class _ManageUsersViewState extends State<ManageUsersView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedRoleFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUserModel;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('User details not found. Please log in.')),
      );
    }

    final provider = Provider.of<ManageUsersProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          'Manage Users',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline),
                  const SizedBox(width: 8),
                  Text('Users List', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history_toggle_off_outlined),
                  const SizedBox(width: 8),
                  Text('Audit Logs', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersTab(context, currentUser, provider),
          _buildAuditLogsTab(context, provider),
        ],
      ),
    );
  }

  Widget _buildUsersTab(BuildContext context, UserModel currentUser, ManageUsersProvider provider) {
    return Column(
      children: [
        // Search & Role Filter Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              // Search Input
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Teacher', 'Intern'].map((role) {
                    final isSelected = _selectedRoleFilter == role;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(role),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedRoleFilter = role;
                            });
                          }
                        },
                        selectedColor: Theme.of(context).colorScheme.primary,
                        labelStyle: GoogleFonts.inter(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: const Color(0xFFF3F4F6),
                        checkmarkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        // Users Stream
        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: provider.streamUsers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: GoogleFonts.inter(color: Colors.red),
                  ),
                );
              }

              final allUsers = snapshot.data ?? [];
              final filteredUsers = allUsers.where((user) {
                // Hide Principal accounts completely from the list of staff users
                if (user.role.toLowerCase() == 'principal') {
                  return false;
                }
                // Filter by role
                if (_selectedRoleFilter != 'All' && user.role.toLowerCase() != _selectedRoleFilter.toLowerCase()) {
                  return false;
                }
                // Filter by search query
                if (_searchController.text.isNotEmpty) {
                  final query = _searchController.text.toLowerCase();
                  return user.name.toLowerCase().contains(query) || user.email.toLowerCase().contains(query);
                }
                return true;
              }).toList();

              if (filteredUsers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No matching users found',
                        style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  return _buildUserCard(context, filteredUsers[index], currentUser, provider);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    UserModel targetUser,
    UserModel currentUser,
    ManageUsersProvider provider,
  ) {
    final nameParts = targetUser.name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    final initials = nameParts.length >= 2
        ? '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase()
        : targetUser.name.isNotEmpty
            ? targetUser.name[0].toUpperCase()
            : '?';

    final isActive = targetUser.status.toLowerCase() == 'active';
    final isSelf = targetUser.id == currentUser.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: targetUser.status.toLowerCase() == 'inactive'
            ? BorderSide(color: Colors.grey.shade300, width: 1)
            : BorderSide.none,
      ),
      elevation: isActive ? 2 : 1,
      color: isActive ? Colors.white : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Initials Avatar
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(isActive ? 0.1 : 0.05),
                  child: Text(
                    initials,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary.withOpacity(isActive ? 1.0 : 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // User Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              targetUser.name.isNotEmpty ? targetUser.name : '(No Name)',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isActive ? const Color(0xFF1F2937) : Colors.grey.shade600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              targetUser.status,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        targetUser.email,
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      if (targetUser.phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Phone: ${targetUser.phone}',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 14, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Text(
                            targetUser.role,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
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
            const Divider(),
            const SizedBox(height: 8),
            // User Action Buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Edit Profile
                  ElevatedButton.icon(
                    onPressed: () => _showEditProfileDialog(context, targetUser, currentUser, provider),
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade700,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Assign Intern as Teacher (promotion button)
                  if (targetUser.role.toLowerCase() == 'intern') ...[
                    ElevatedButton.icon(
                      onPressed: () => _confirmAssignAsTeacher(context, targetUser, currentUser, provider),
                      icon: const Icon(Icons.check_circle_outline, size: 14),
                      label: const Text('Assign as Teacher'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade50,
                        foregroundColor: Colors.green.shade700,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Reset Password Email Link
                  ElevatedButton.icon(
                    onPressed: () => _confirmResetPassword(context, targetUser, currentUser, provider),
                    icon: const Icon(Icons.lock_open, size: 14),
                    label: const Text('Reset Password'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade50,
                      foregroundColor: Colors.orange.shade800,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Toggle Status (Activate / Deactivate)
                  if (!isSelf)
                    ElevatedButton.icon(
                      onPressed: () => _confirmToggleStatus(context, targetUser, currentUser, provider),
                      icon: Icon(isActive ? Icons.block : Icons.check, size: 14),
                      label: Text(isActive ? 'Deactivate' : 'Activate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isActive ? Colors.red.shade50 : Colors.teal.shade50,
                        foregroundColor: isActive ? Colors.red.shade700 : Colors.teal.shade700,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditLogsTab(BuildContext context, ManageUsersProvider provider) {
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: provider.streamAuditLogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading logs: ${snapshot.error}',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          );
        }

        final logs = snapshot.data ?? [];

        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No administrator changes logged yet.',
                  style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey.shade600),
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
            final DateTime createdAt = log['createdAt'] as DateTime;
            final String action = log['action'];
            final String targetUserName = log['targetUserName'];
            final String oldValue = log['oldValue'];
            final String newValue = log['newValue'];
            final String changedByName = log['changedByName'];

            IconData iconData;
            Color iconColor;
            Color iconBg;

            switch (action) {
              case 'Role Changed':
                iconData = Icons.badge_outlined;
                iconColor = Colors.blue.shade700;
                iconBg = Colors.blue.shade50;
                break;
              case 'Account Deactivated':
                iconData = Icons.block;
                iconColor = Colors.red.shade700;
                iconBg = Colors.red.shade50;
                break;
              case 'Account Activated':
                iconData = Icons.check_circle_outline;
                iconColor = Colors.teal.shade700;
                iconBg = Colors.teal.shade50;
                break;
              case 'Password Reset Sent':
                iconData = Icons.lock_outline;
                iconColor = Colors.orange.shade800;
                iconBg = Colors.orange.shade50;
                break;
              case 'Profile Edited':
                iconData = Icons.edit_outlined;
                iconColor = Colors.purple.shade700;
                iconBg = Colors.purple.shade50;
                break;
              default:
                iconData = Icons.info_outline;
                iconColor = Colors.grey.shade700;
                iconBg = Colors.grey.shade100;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: iconBg,
                      child: Icon(iconData, color: iconColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            action,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Log Message
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF4B5563)),
                              children: [
                                const TextSpan(text: 'Target: '),
                                TextSpan(
                                  text: targetUserName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (oldValue.isNotEmpty || newValue.isNotEmpty) ...[
                            Text(
                              'Change: $oldValue → $newValue',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'By: $changedByName',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                dateFormat.format(createdAt),
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditProfileDialog(
    BuildContext context,
    UserModel userToEdit,
    UserModel currentUser,
    ManageUsersProvider provider,
  ) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: userToEdit.name);
    final emailController = TextEditingController(text: userToEdit.email);
    final phoneController = TextEditingController(text: userToEdit.phone);
    String selectedRole = userToEdit.role;
    String selectedStatus = userToEdit.status;

    final bool isSelf = userToEdit.id == currentUser.id;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Edit User Profile',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v!.isEmpty ? 'Please enter a name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          if (v!.isEmpty) return 'Please enter an email';
                          if (!v.contains('@')) return 'Invalid email format';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: ['Teacher', 'Intern']
                            .map((role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(role),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedRole = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: ['Active', 'Inactive']
                            .map((status) => DropdownMenuItem(
                                  value: status,
                                  enabled: !isSelf || status == 'Active', // Cannot deactivate self
                                  child: Text(status),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedStatus = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(dialogContext);
                      final success = await provider.updateUserProfile(
                        uid: userToEdit.id,
                        name: nameController.text.trim(),
                        email: emailController.text.trim(),
                        phone: phoneController.text.trim(),
                        role: selectedRole,
                        status: selectedStatus,
                        changedBy: currentUser,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Profile updated successfully'
                                  : 'Failed to update: ${provider.errorMessage ?? "Error"}',
                            ),
                            backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmAssignAsTeacher(
    BuildContext context,
    UserModel targetUser,
    UserModel currentUser,
    ManageUsersProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Assign as Teacher',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to promote ${targetUser.name} from Intern to Teacher?\n\nThey will gain access to all teacher duties and features.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await provider.assignInternAsTeacher(
                uid: targetUser.id,
                name: targetUser.name,
                changedBy: currentUser,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '${targetUser.name} is now a permanent Teacher.'
                          : 'Failed to assign: ${provider.errorMessage ?? "Error"}',
                    ),
                    backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Confirm', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmToggleStatus(
    BuildContext context,
    UserModel targetUser,
    UserModel currentUser,
    ManageUsersProvider provider,
  ) {
    final isActive = targetUser.status.toLowerCase() == 'active';
    final actionText = isActive ? 'Deactivate' : 'Activate';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '$actionText User Account',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isActive
              ? 'Are you sure you want to deactivate ${targetUser.name}\'s account?\n\nThey will be signed out and blocked from logging in. Historical records and details will remain saved in the system.'
              : 'Are you sure you want to activate ${targetUser.name}\'s account?\n\nThey will be able to log in and access the system with their role.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await provider.toggleAccountStatus(
                uid: targetUser.id,
                name: targetUser.name,
                currentStatus: targetUser.status,
                changedBy: currentUser,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Account status updated to ${isActive ? "Inactive" : "Active"}.'
                          : 'Failed to toggle: ${provider.errorMessage ?? "Error"}',
                    ),
                    backgroundColor: success ? Theme.of(context).colorScheme.primary : Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? Colors.red.shade700 : Colors.teal.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Confirm', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmResetPassword(
    BuildContext context,
    UserModel targetUser,
    UserModel currentUser,
    ManageUsersProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset Password',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Send a secure password reset email link to ${targetUser.email}?\n\nThe user can reset their password via that link.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await provider.sendPasswordReset(
                email: targetUser.email,
                targetUserId: targetUser.id,
                targetUserName: targetUser.name,
                changedBy: currentUser,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Password reset email sent to ${targetUser.email}.'
                          : 'Failed: ${provider.errorMessage ?? "Error"}',
                    ),
                    backgroundColor: success ? Colors.orange.shade800 : Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Send Link', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
