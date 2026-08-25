// 📁 providers/role_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/role.dart';
import 'package:frontend/services/api_services.dart';
import 'package:frontend/providers/api_providers.dart';

// ============================================================
// STATE
// ============================================================
class RoleState {
  final List<Role> roles;
  final bool isLoading;
  final String? errorMessage;

  RoleState({
    required this.roles,
    required this.isLoading,
    this.errorMessage,
  });

  factory RoleState.initial() {
    return RoleState(
      roles: [],
      isLoading: false,
      errorMessage: null,
    );
  }

  RoleState copyWith({
    List<Role>? roles,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RoleState(
      roles: roles ?? this.roles,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ============================================================
// NOTIFIER
// ============================================================
class RoleNotifier extends StateNotifier<RoleState> {
  final ApiService _api;

  RoleNotifier(this._api) : super(RoleState.initial());

  Future<void> loadRoles() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final roles = await _api.getAllRoles();
      state = state.copyWith(
        roles: roles,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> createRole(String roleName) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final newRole = await _api.createRole(roleName);
      state = state.copyWith(
        roles: [...state.roles, newRole],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ============================================================
// PROVIDER
// ============================================================
final roleProvider = StateNotifierProvider<RoleNotifier, RoleState>((ref) {
  return RoleNotifier(ref.watch(apiProvider));
});
