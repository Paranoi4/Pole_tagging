// 📁 lib/providers/crew_provider.dart
//
// Mirrors duProvider: a small StateNotifier holding the crew list plus
// loading/error flags, so any screen can `ref.watch(crewProvider)` and
// `ref.read(crewProvider.notifier).loadCrews()` without re-fetching or
// re-implementing the fetch-state dance itself.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/models/crew.dart';
import 'package:frontend/providers/api_providers.dart';
import 'package:frontend/services/api_exception.dart';

class CrewState {
  final List<Crew> crews;
  final bool isLoading;
  final String? errorMessage;

  const CrewState({
    this.crews = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  CrewState copyWith({
    List<Crew>? crews,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CrewState(
      crews: crews ?? this.crews,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class CrewNotifier extends StateNotifier<CrewState> {
  final Ref ref;

  CrewNotifier(this.ref) : super(const CrewState());

  /// Fetches every crew for the caller's org (walking all pages), replacing
  /// whatever was loaded before. Safe to call again to refresh — e.g. after
  /// a crew is added.
  Future<void> loadCrews() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final crews = await ref.read(apiProvider).getAllCrews();
      state = state.copyWith(crews: crews, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }
}

final crewProvider = StateNotifierProvider<CrewNotifier, CrewState>(
  (ref) => CrewNotifier(ref),
);
