import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/providers/auth_providers.dart';
import 'package:frontend/screens/home_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/no_roles_screen.dart';
import 'package:frontend/screens/profile_screen.dart';
import 'package:frontend/screens/register_screen.dart';
import 'package:frontend/screens/roles_screen.dart';
import 'package:frontend/screens/users_screen.dart';
import 'package:frontend/screens/printerman_screen.dart';
import 'package:frontend/screens/dispatcher_screen.dart';

class AppRouter extends ConsumerStatefulWidget {
  const AppRouter({super.key});

  @override
  ConsumerState<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends ConsumerState<AppRouter> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final GoRouter _router;
  bool _isBootstrapping = true;

  @override
  void initState() {
    super.initState();

    // Capture Google's redirect params (if any) BEFORE constructing
    // GoRouter. GoRouter's `initialLocation: '/login'` below forces the
    // browser URL to bare '/login' as soon as it initializes on a fresh
    // page load — which is exactly what a Google OAuth redirect is — so
    // Uri.base has to be read here, synchronously, before that happens.
    // Reading it later (even in a Future.microtask right after) can be too
    // late: the query string may already be gone from the address bar.
    final initialUri = Uri.base;
    final googleToken = initialUri.queryParameters['token'];
    final isGoogleAuth = initialUri.queryParameters['google_auth'] == 'true';

    _router = GoRouter(
      navigatorKey: _navigatorKey,
      initialLocation: '/login',
      redirect: (_, state) {
        if (_isBootstrapping) return null;

        final isPublicRoute =
            state.uri.path == '/login' || state.uri.path == '/register';
        if (!ref.read(authProvider).isAuthenticated && !isPublicRoute) {
          return '/login';
        }
        if (ref.read(authProvider).isAuthenticated && isPublicRoute) {
          return _initialRouteForUser();
        }
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: '/no-roles',
          builder: (_, __) => const NoRolesScreen(),
        ),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        GoRoute(path: '/users', builder: (_, __) => const UsersScreen()),
        GoRoute(path: '/roles', builder: (_, __) => const RolesScreen()),
        // Neither screen is handed a role flag here. Route builders run before
        // the loadUser() below has restored the session, so anything computed
        // from authProvider at this point is false on a browser refresh and,
        // being a constructor argument, never corrects itself once the roles
        // arrive. Each screen watches authProvider itself instead.
        GoRoute(
          path: '/printerman',
          builder: (_, __) => const PrinterManScreen(),
        ),
        GoRoute(
          path: '/dispatcher',
          builder: (_, __) => const DispatcherScreen(),
        ),
      ],
    );
    Future.microtask(() async {
      // The googleToken/isGoogleAuth values were already captured above,
      // synchronously, before GoRouter's construction had any chance to
      // touch the URL — this block just does the async work of saving it.
      if (isGoogleAuth && googleToken != null && googleToken.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', googleToken);
      }

      await ref.read(authProvider.notifier).loadUser();
      if (!mounted) return;
      setState(() => _isBootstrapping = false);
      _navigateForAuth(ref.read(authProvider).isAuthenticated);
    });
  }

  void _navigateForAuth(bool isAuthenticated) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _router.go(isAuthenticated ? _initialRouteForUser() : '/login');
    });
  }

  String _initialRouteForUser() {
    final roles =
        ref.read(authProvider).user?.roles.map((role) => role.roleName).toSet();

    if (roles == null || roles.isEmpty) return '/no-roles';
    if (roles.contains('Printerman')) return '/printerman';
    if (roles.contains('Dispatcher')) return '/dispatcher';
    return '/home';
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!_isBootstrapping &&
          previous?.isAuthenticated != next.isAuthenticated) {
        _navigateForAuth(next.isAuthenticated);
      }
    });

    return MaterialApp.router(
      title: 'Poletagging',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
