import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/providers/auth_providers.dart';

/// Shown when a user is authenticated but has no roles assigned yet.
/// No drawer, no nav — just a message and a way out (logout) or a way to
/// check again (pull to refresh) once an admin has assigned a role.
class NoRolesScreen extends ConsumerWidget {
  const NoRolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Poletagging'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        // Pull to refresh re-checks /me in case an admin just assigned a
        // role — see AuthNotifier.refreshUser() in auth_providers.dart.
        onRefresh: () => ref.read(authProvider.notifier).refreshUser(),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_clock,
                        size: 72,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'No roles assigned yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your account has been created, but you don\'t have '
                        'access to any screens yet. Contact your '
                        'administrator to get a role assigned.',
                        style: TextStyle(fontSize: 15, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Pull down to check again',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
