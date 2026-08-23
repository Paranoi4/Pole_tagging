import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/providers/auth_providers.dart';
import 'package:frontend/screens/home_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/profile_screen.dart';
import 'package:frontend/screens/register_screen.dart';
import 'package:frontend/screens/roles_screen.dart';
import 'package:frontend/screens/users_screens.dart';

class AppRouter extends ConsumerStatefulWidget {
  const AppRouter({super.key});

  @override
  ConsumerState<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends ConsumerState<AppRouter> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authProvider.notifier).loadUser());
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (authState.isLoading) {
      return MaterialApp(
        title: 'Poletagging',
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Poletagging',
      debugShowCheckedModeBanner: false,
      initialRoute: authState.isAuthenticated ? '/home' : '/login',
      onGenerateRoute: (settings) {
        final routeName = settings.name ?? '/login';
        final protectedRoutes = {'/home', '/profile', '/users', '/roles'};

        if (protectedRoutes.contains(routeName) && !authState.isAuthenticated) {
          return MaterialPageRoute(builder: (_) => const LoginScreen());
        }

        return null;
      },
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/register': (context) => const RegisterScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/users': (context) => const UsersScreen(),
        '/roles': (context) => const RolesScreen(),
      },
    );
  }
}
