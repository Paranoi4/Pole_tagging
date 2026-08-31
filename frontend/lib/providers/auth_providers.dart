import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/api_providers.dart';
import 'package:frontend/providers/crew_provider.dart';
import 'package:frontend/providers/du_provider.dart';
import 'package:frontend/services/api_services.dart';

class AuthState {
  final User? user;
  final String? token;
  final bool isLoading;
  final bool isAuthenticated;
  final String? errorMessage;

  AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.errorMessage,
  });

  /// Copies the state, changing only what is passed.
  ///
  /// `user` and `token` are already nullable, so passing null cannot mean
  /// "clear it" - `null ?? this.user` keeps the old value. Logging out has to
  /// say so explicitly with [clearUser] / [clearToken], otherwise the previous
  /// user and their token stay in memory behind a logged-out screen.
  AuthState copyWith({
    User? user,
    String? token,
    bool? isLoading,
    bool? isAuthenticated,
    String? errorMessage,
    bool clearUser = false,
    bool clearToken = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      token: clearToken ? null : (token ?? this.token),
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      errorMessage: errorMessage,
    );
  }

  factory AuthState.initial() {
    return AuthState(isLoading: true);
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;
  final Ref _ref;
  Timer? _tokenExpiryTimer;

  AuthNotifier(this._api, this._ref) : super(AuthState.initial());

  /// Providers that cache data scoped to the signed-in user's org (DUs,
  /// crews, ...). Without this, whatever the previous admin had loaded
  /// stays put — e.g. an NP admin's DU list showing up for a BP admin who
  /// logs in right after, since duProvider/crewProvider live for the whole
  /// app lifetime and only refetch when empty.
  ///
  /// Add any future org-scoped provider here too.
  void _resetOrgScopedCaches() {
    _ref.invalidate(duProvider);
    _ref.invalidate(crewProvider);
  }

  static DateTime? parseTokenExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;

      final payload = parts[1];
      final normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      final padded = normalized.padRight((normalized.length + 3) ~/ 4 * 4, '=');
      final decoded = utf8.decode(base64Url.decode(padded));
      final payloadMap = jsonDecode(decoded);

      if (payloadMap is! Map<String, dynamic>) return null;
      final exp = payloadMap['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      }
      if (exp is double) {
        return DateTime.fromMillisecondsSinceEpoch(exp.round() * 1000,
            isUtc: true);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _scheduleTokenExpiry(String? token) {
    _tokenExpiryTimer?.cancel();

    if (token == null || token.isEmpty) return;

    final expiry = parseTokenExpiry(token);
    if (expiry == null) return;

    final remaining = expiry.difference(DateTime.now().toUtc());

    if (remaining <= Duration.zero) {
      Future.microtask(logout);
      return;
    }

    _tokenExpiryTimer = Timer(remaining, () {
      logout();
    });
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final loginResponse = await _api.login(username, password);
      final token = loginResponse.accessToken;
      final user = loginResponse.user;

      // Hand the token to the service before anything else can make a call.
      _api.setToken(token);

      // Save token to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

      // New session, possibly a different org — drop whatever the last
      // signed-in user had cached before anything reads it.
      _resetOrgScopedCaches();

      state = state.copyWith(
        user: user,
        token: token,
        isAuthenticated: true,
        isLoading: false,
        errorMessage: null,
      );

      _scheduleTokenExpiry(token);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> register(User user, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _api.register(user, password);

      // After registration, login automatically
      await login(user.username, password);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadUser() async {
    state = state.copyWith(isLoading: true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _api.setToken(null);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        clearUser: true,
        clearToken: true,
      );
      return;
    }

    try {
      // Restore the saved token onto the service before the call that uses it.
      _api.setToken(token);
      final user = await _api.getCurrentUser();
      state = state.copyWith(
        user: user,
        token: token,
        isAuthenticated: true,
        isLoading: false,
      );
      _scheduleTokenExpiry(token);
    } catch (e) {
      // Token is invalid or expired
      await logout();
    }
  }

  /// Re-fetches /me and updates only the user in state, keeping the existing
  /// token and isAuthenticated as-is. Used by pull-to-refresh (e.g. on
  /// NoRolesScreen) so a role an admin just assigned shows up without
  /// forcing a logout/login.
  Future<void> refreshUser() async {
    try {
      final user = await _api.getCurrentUser();
      state = state.copyWith(user: user);
    } catch (e) {
      // A 401 here means the token died between requests - same handling
      // as loadUser()'s failure path.
      await logout();
    }
  }

  Future<void> logout() async {
    _tokenExpiryTimer?.cancel();
    _tokenExpiryTimer = null;

    _api.setToken(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');

    state = state.copyWith(
      clearUser: true,
      clearToken: true,
      isAuthenticated: false,
      isLoading: false,
    );

    _resetOrgScopedCaches();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(apiProvider), ref);
});
