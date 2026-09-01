// lib/providers/stats_provider.dart
//
// The dashboards' stat rows. One provider per role rather than one shared
// state: each role's dashboard reports different numbers, so a single state
// object would rebuild the printerman's tiles whenever the dispatcher's
// figures were refreshed.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/printerman_stats.dart';
import 'package:frontend/services/api_services.dart';
import 'package:frontend/providers/api_providers.dart';

class PrintermanStatsState {
  final PrintermanStats? stats;
  final bool isLoading;
  final String? errorMessage;

  const PrintermanStatsState({
    this.stats,
    this.isLoading = false,
    this.errorMessage,
  });

  factory PrintermanStatsState.initial() => const PrintermanStatsState();

  PrintermanStatsState copyWith({
    PrintermanStats? stats,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PrintermanStatsState(
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PrintermanStatsNotifier extends StateNotifier<PrintermanStatsState> {
  final ApiService _api;

  PrintermanStatsNotifier(this._api) : super(PrintermanStatsState.initial());

  /// The DU the figures on screen belong to, so a reload after printing can
  /// refresh them without the caller having to remember which DU was picked.
  int? _duId;

  Future<void> load(int duId) async {
    _duId = duId;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final stats = await _api.getPrintermanStats(duId);
      state = state.copyWith(stats: stats, isLoading: false);
    } catch (e) {
      // The tiles keep their last figures on a failed refresh rather than
      // dropping to zero, which would read as "the pool is empty".
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Re-reads the DU already loaded. A no-op before the first [load].
  Future<void> refresh() async {
    final duId = _duId;
    if (duId != null) await load(duId);
  }
}

final printermanStatsProvider =
    StateNotifierProvider<PrintermanStatsNotifier, PrintermanStatsState>((ref) {
  return PrintermanStatsNotifier(ref.watch(apiProvider));
});
