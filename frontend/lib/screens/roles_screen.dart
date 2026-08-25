// 📁 lib/screens/roles_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/role.dart';
import 'package:frontend/providers/role_provider.dart'; // ← NEW IMPORT

class RolesScreen extends ConsumerStatefulWidget {
  const RolesScreen({super.key});

  @override
  ConsumerState<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends ConsumerState<RolesScreen> {
  // ❌ REMOVED: List<Role> roles = [];
  // ❌ REMOVED: bool isLoading = true;
  // ❌ REMOVED: String? error;

  @override
  void initState() {
    super.initState();
    // ✅ Load roles through provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roleProvider.notifier).loadRoles();
    });
  }

  // ❌ REMOVED: Future<void> _loadRoles() async { ... }

  @override
  Widget build(BuildContext context) {
    // ✅ Watch the provider for state
    final roleState = ref.watch(roleProvider);
    final notifier = ref.read(roleProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: notifier.loadRoles, // ✅ Call provider action
          ),
        ],
      ),
      body: roleState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : roleState.errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: ${roleState.errorMessage}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: notifier.loadRoles, // ✅ Call provider action
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : roleState.roles.isEmpty
                  ? const Center(child: Text('No roles found'))
                  : ListView.builder(
                      itemCount: roleState.roles.length,
                      itemBuilder: (context, index) {
                        final role = roleState.roles[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple,
                            child: Text(
                              role.roleName.isNotEmpty
                                  ? role.roleName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(role.roleName),
                          subtitle: Text('ID: ${role.roleId}'),
                          trailing: Text(
                            role.updatedAt?.toString().substring(0, 10) ??
                                'N/A',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        );
                      },
                    ),
    );
  }
}
