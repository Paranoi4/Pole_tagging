import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/models/user.dart';
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

  AuthState copyWith({
    User? user,
    String? token,
    bool? isLoading,
    bool? isAuthenticated,
    String? errorMessage,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      errorMessage: errorMessage,
    );
  }

  factory AuthState.initial() {
    return AuthState();
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  Timer? _tokenExpiryTimer;

  AuthNotifier() : super(AuthState.initial());

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
      final loginResponse = await ApiService.login(username, password);
      final token = loginResponse.accessToken;
      final user = loginResponse.user;

      // Save token to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

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
    }
  }

  Future<void> register(User user, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await ApiService.register(user, password);

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
      state = state.copyWith(isLoading: false, isAuthenticated: false, user: null, token: null);
      return;
    }

    try {
      final user = await ApiService.getCurrentUser(token);
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

  Future<void> logout() async {
    _tokenExpiryTimer?.cancel();
    _tokenExpiryTimer = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');

    state = state.copyWith(
      user: null,
      token: null,
      isAuthenticated: false,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
