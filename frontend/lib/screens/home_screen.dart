import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/providers/auth_providers.dart';
import 'package:frontend/screens/no_roles_screen.dart';
import 'package:frontend/screens/printerman_screen.dart';
import 'package:frontend/screens/dispatcher_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (!authState.isAuthenticated || user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // A user can hold zero, one, or both of Printerman/Dispatcher (plus
    // Admin). Zero roles gets its own screen instead of an empty dashboard.
    final roleNames = user.roles.map((r) => r.roleName).toSet();
    final isAdmin = roleNames.contains('Admin');
    final isPrinterman = roleNames.contains('Printerman');
    final isDispatcher = roleNames.contains('Dispatcher');

    if (roleNames.isEmpty) {
      return const NoRolesScreen();
    }

    // Admins keep this generic dashboard so the drawer (Users/Roles) stays
    // one tap away. A non-Admin Printerman or Dispatcher instead lands
    // directly on their working screen rather than this placeholder — with
    // a Dispatcher shortcut icon added to Printerman's app bar for anyone
    // holding both roles.
    if (!isAdmin) {
      if (isPrinterman) {
        return PrinterManScreen(showDispatcherShortcut: isDispatcher);
      }
      if (isDispatcher) {
        return const DispatcherScreen();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Poletagging'),
        actions: [
          if (isPrinterman)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Printerman',
              onPressed: () {
                context.push('/printerman');
              },
            ),
          if (isDispatcher)
            IconButton(
              icon: const Icon(Icons.local_shipping),
              tooltip: 'Dispatcher',
              onPressed: () {
                context.push('/dispatcher');
              },
            ),
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
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.blue,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    user?.fullName ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user?.username ?? '',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            // Admin-only: manage users (assign/remove roles) and view roles.
            // Backend already rejects non-Admins on the underlying calls;
            // hiding the entries here just keeps the nav honest.
            if (isAdmin) ...[
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Users'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/users');
                },
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Roles'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/roles');
                },
              ),
            ],
            if (isPrinterman)
              ListTile(
                leading: const Icon(Icons.print),
                title: const Text('Printerman'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/printerman');
                },
              ),
            if (isDispatcher)
              ListTile(
                leading: const Icon(Icons.local_shipping),
                title: const Text('Dispatcher'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/dispatcher');
                },
              ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                context.push('/profile');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
      body: Container(),
    );
  }
}
