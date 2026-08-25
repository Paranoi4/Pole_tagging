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
