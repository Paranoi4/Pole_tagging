// 📁 providers/user_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/services/api_services.dart';
import 'package:frontend/providers/api_providers.dart';

// ============================================================
// STATE
// ============================================================
class UserState {
  final List<User> users;
  final bool isLoading;
  final String? errorMessage;

  UserState({
    required this.users,
    required this.isLoading,
    this.errorMessage,
  });

  factory UserState.initial() {
    return UserState(
      users: [],
      isLoading: false,
      errorMessage: null,
    );
  }

  UserState copyWith({
    List<User>? users,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UserState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ============================================================
// NOTIFIER
// ============================================================
class UserNotifier extends StateNotifier<UserState> {
  final ApiService _api;

  UserNotifier(this._api) : super(UserState.initial());

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final users = await _api.getAllUsers();
      state = state.copyWith(
        users: users,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> createUser(User user, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final newUser = await _api.createUser(user, password);
      state = state.copyWith(
        users: [...state.users, newUser],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> deleteUser(int userId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _api.deleteUser(userId);
      final updatedUsers =
          state.users.where((u) => u.userId != userId).toList();
      state = state.copyWith(
        users: updatedUsers,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Reconciles [userId]'s roles to exactly [desiredRoleIds] — assigns any
  /// missing ones, removes any it currently has that aren't in the set.
  /// Used by the role-assign bottom sheet, which lets an Admin check/uncheck
  /// several roles and save once rather than one call per toggle.
  Future<void> updateUserRoles(int userId, Set<int> desiredRoleIds) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // The diff is computed against what the server holds right now, not the
      // cached copy in state. A list loaded a minute ago can already be stale —
      // another admin removing a role would otherwise be silently undone here,
      // because this would "keep" a role the server no longer has. It also
      // means a deleted user surfaces as the backend's 404 instead of throwing
      // out of firstWhere before the try block is even entered.
      final current = await _api.getUserById(userId);
      final currentRoleIds = current.roles.map((r) => r.roleId).toSet();

      final toAdd = desiredRoleIds.difference(currentRoleIds);
      final toRemove = currentRoleIds.difference(desiredRoleIds);

      for (final roleId in toAdd) {
        await _api.assignRoleToUser(userId, roleId);
      }
      for (final roleId in toRemove) {
        await _api.removeRoleFromUser(userId, roleId);
      }

      // Re-fetch this one user rather than the whole list — cheaper, and
      // guarantees the roles shown match what the backend actually saved.
      final updatedUser = await _api.getUserById(userId);
      final updatedUsers =
          state.users.map((u) => u.userId == userId ? updatedUser : u).toList();

      state = state.copyWith(users: updatedUsers, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ============================================================
// PROVIDER
// ============================================================
final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier(ref.watch(apiProvider));
});
