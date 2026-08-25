// 📁 lib/screens/users_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/models/role.dart';
import 'package:frontend/providers/user_provider.dart';
import 'package:frontend/providers/role_provider.dart';
import 'package:frontend/providers/auth_providers.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProvider.notifier).loadUsers();
      // Roles have to be loaded too — the role-assign sheet needs the full
      // list (Admin/Printerman/Dispatcher) to build its checkboxes.
      ref.read(roleProvider.notifier).loadRoles();
    });
  }

  void _openRoleSheet(User user, List<Role> allRoles) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _RoleAssignSheet(user: user, allRoles: allRoles),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final roleState = ref.watch(roleProvider);
    final notifier = ref.read(userProvider.notifier);
    final currentUsername = ref.watch(authProvider).user?.username;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: notifier.loadUsers,
          ),
        ],
      ),
      body: userState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : userState.errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: ${userState.errorMessage}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: notifier.loadUsers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : userState.users.isEmpty
                  ? const Center(child: Text('No users found'))
                  : ListView.builder(
                      itemCount: userState.users.length,
                      itemBuilder: (context, index) {
                        final user = userState.users[index];
                        final isSelf = user.username == currentUsername;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Text(
                              user.firstName.isNotEmpty
                                  ? user.firstName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(user.fullName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.username),
                              const SizedBox(height: 6),
                              if (user.roles.isEmpty)
                                Text(
                                  'No roles assigned',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 6,
                                  runSpacing: -8,
                                  children: user.roles
                                      .map((r) => Chip(
                                            label: Text(
                                              r.roleName,
                                              style:
                                                  const TextStyle(fontSize: 11),
                                            ),
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            visualDensity:
                                                VisualDensity.compact,
                                            backgroundColor:
                                                Colors.blue.shade50,
                                          ))
                                      .toList(),
                                ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Chip(
                                label: Text(
                                  user.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: user.isActive
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: isSelf
                                    ? 'Edit your own roles'
                                    : 'Edit roles',
                                onPressed: roleState.roles.isEmpty
                                    ? null
                                    : () =>
                                        _openRoleSheet(user, roleState.roles),
                              ),
                            ],
                          ),
                          onTap: roleState.roles.isEmpty
                              ? null
                              : () => _openRoleSheet(user, roleState.roles),
                        );
                      },
                    ),
    );
  }
}

/// Bottom sheet: checkbox per role, "Save" reconciles them via
/// UserNotifier.updateUserRoles (diff-based add/remove, one save action).
class _RoleAssignSheet extends ConsumerStatefulWidget {
  final User user;
  final List<Role> allRoles;

  const _RoleAssignSheet({required this.user, required this.allRoles});

  @override
  ConsumerState<_RoleAssignSheet> createState() => _RoleAssignSheetState();
}

class _RoleAssignSheetState extends ConsumerState<_RoleAssignSheet> {
  late Set<int> _selectedRoleIds;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedRoleIds = widget.user.roles.map((r) => r.roleId).toSet();
  }

  bool get _removingOwnAdmin {
    final currentUsername = ref.read(authProvider).user?.username;
    if (currentUsername != widget.user.username) return false;

    final adminRole = widget.allRoles.where((r) => r.roleName == 'Admin');
    if (adminRole.isEmpty) return false;

    final adminId = adminRole.first.roleId;
    final hadAdmin = widget.user.roles.any((r) => r.roleId == adminId);
    return hadAdmin && !_selectedRoleIds.contains(adminId);
  }

  Future<void> _save() async {
    if (_removingOwnAdmin) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Remove your own Admin role?'),
          content: const Text(
            'You are about to remove your own Admin access. If no other '
            'Admin exists, no one will be able to assign roles afterward.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove anyway'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref
          .read(userProvider.notifier)
          .updateUserRoles(widget.user.userId, _selectedRoleIds);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isSaving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.user.fullName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            widget.user.username,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          const Text(
            'Roles',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          ...widget.allRoles.map((role) {
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(role.roleName),
              value: _selectedRoleIds.contains(role.roleId),
              onChanged: _isSaving
                  ? null
                  : (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedRoleIds.add(role.roleId);
                        } else {
                          _selectedRoleIds.remove(role.roleId);
                        }
                      });
                    },
            );
          }),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
