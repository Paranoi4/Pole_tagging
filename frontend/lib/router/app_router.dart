import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/providers/auth_providers.dart';
import 'package:frontend/screens/home_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/profile_screen.dart';
import 'package:frontend/screens/register_screen.dart';
import 'package:frontend/screens/roles_screen.dart';
import 'package:frontend/screens/users_screen.dart';

class AppRouter extends ConsumerStatefulWidget {
  const AppRouter({super.key});

  @override
  ConsumerState<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends ConsumerState<AppRouter> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _isBootstrapping = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(authProvider.notifier).loadUser();
      if (!mounted) return;
      setState(() => _isBootstrapping = false);
      _navigateForAuth(ref.read(authProvider).isAuthenticated);
    });
  }

  void _navigateForAuth(bool isAuthenticated) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        isAuthenticated ? '/home' : '/login',
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!_isBootstrapping &&
          previous?.isAuthenticated != next.isAuthenticated) {
        _navigateForAuth(next.isAuthenticated);
      }
    });

    final authState = ref.watch(authProvider);

    if (_isBootstrapping) {
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
      navigatorKey: _navigatorKey,
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        final routeName = settings.name ?? '/login';
        final protectedRoutes = {'/home', '/profile', '/users', '/roles'};

        if (protectedRoutes.contains(routeName) && !authState.isAuthenticated) {
          return MaterialPageRoute(builder: (_) => const LoginScreen());
        }

        switch (routeName) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          case '/register':
            return MaterialPageRoute(builder: (_) => const RegisterScreen());
          case '/profile':
            return MaterialPageRoute(builder: (_) => const ProfileScreen());
          case '/users':
            return MaterialPageRoute(builder: (_) => const UsersScreen());
          case '/roles':
            return MaterialPageRoute(builder: (_) => const RolesScreen());
          default:
            return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
      },
    );
  }
}
