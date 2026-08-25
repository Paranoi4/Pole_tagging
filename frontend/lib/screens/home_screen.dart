import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/providers/auth_providers.dart';
import 'package:frontend/screens/profile_screen.dart';
import 'package:frontend/screens/users_screen.dart';
import 'package:frontend/screens/roles_screen.dart';
import 'package:frontend/screens/printerman_screen.dart';
import 'package:frontend/screens/dispatcher_screen.dart';
import 'package:frontend/screens/no_roles_screen.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Poletagging'),
        actions: [
          if (isPrinterman)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Printerman',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrinterManScreen()),
                );
              },
            ),
          if (isDispatcher)
            IconButton(
              icon: const Icon(Icons.local_shipping),
              tooltip: 'Dispatcher',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DispatcherScreen()),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UsersScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Roles'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RolesScreen()),
                  );
                },
              ),
            ],
            if (isPrinterman)
              ListTile(
                leading: const Icon(Icons.print),
                title: const Text('Printerman'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrinterManScreen()),
                  );
                },
              ),
            if (isDispatcher)
              ListTile(
                leading: const Icon(Icons.local_shipping),
                title: const Text('Dispatcher'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DispatcherScreen()),
                  );
                },
              ),
            ListTile(
              // NOTE: this previously opened PrinterManScreen instead of the
              // actual ProfileScreen (which was imported but unused) — fixed
              // here since it looked like a leftover placeholder.
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
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
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome, ${user?.firstName ?? "User"}!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? '',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'Roles:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (user?.roles.isEmpty ?? true)
                    const Text('No roles assigned')
                  else
                    ...user!.roles.map(
                      (role) => Chip(
                        label: Text(role.roleName),
                        backgroundColor: Colors.blue.shade100,
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
}
