// 📁 lib/screens/users_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/user_provider.dart'; // ← NEW IMPORT

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  // ❌ REMOVED: List<User> users = [];
  // ❌ REMOVED: bool isLoading = true;
  // ❌ REMOVED: String? error;

  @override
  void initState() {
    super.initState();
    // ✅ Load users through provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProvider.notifier).loadUsers();
    });
  }

  // ❌ REMOVED: Future<void> _loadUsers() async { ... }

  @override
  Widget build(BuildContext context) {
    // ✅ Watch the provider for state
    final userState = ref.watch(userProvider);
    final notifier = ref.read(userProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: notifier.loadUsers, // ✅ Call provider action
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
                        onPressed: notifier.loadUsers, // ✅ Call provider action
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
                          subtitle: Text(user.username),
                          trailing: Chip(
                            label: Text(
                              user.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color:
                                    user.isActive ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
