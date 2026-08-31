import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/du.dart';
import 'package:frontend/providers/api_providers.dart';
import 'package:frontend/services/api_services.dart';

class DUState {
  final List<DU> dus;
  final DU? selectedDU;
  final String? nextBatchCode;
  final bool isLoading;
  final bool isLoadingNextCode;
  final String? errorMessage;

  const DUState({
    this.dus = const [],
    this.selectedDU,
    this.nextBatchCode,
    this.isLoading = false,
    this.isLoadingNextCode = false,
    this.errorMessage,
  });

  factory DUState.initial() => const DUState();

  DUState copyWith({
    List<DU>? dus,
    DU? selectedDU,
    String? nextBatchCode,
    bool? isLoading,
    bool? isLoadingNextCode,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DUState(
      dus: dus ?? this.dus,
      selectedDU: selectedDU ?? this.selectedDU,
      nextBatchCode: nextBatchCode ?? this.nextBatchCode,
      isLoading: isLoading ?? this.isLoading,
      isLoadingNextCode: isLoadingNextCode ?? this.isLoadingNextCode,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class DUNotifier extends StateNotifier<DUState> {
  final ApiService _api;

  DUNotifier(this._api) : super(DUState.initial());

  Future<void> loadDUs() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dus = await _api.getDUs();
      state = state.copyWith(
        dus: dus,
        isLoading: false,
        selectedDU: dus.isNotEmpty ? dus.first : null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void selectDU(DU du) {
    state = state.copyWith(selectedDU: du);
  }

  /// Asks the server for the code the next batch will get.
  ///
  /// The backend derives it with the same generator that stamps the real
  /// batch. Working it out here instead meant the format lived in two places —
  /// Python and Dart — and it also meant downloading every batch just to find
  /// the highest number.
  Future<void> loadNextBatchCode() async {
    state = state.copyWith(isLoadingNextCode: true, clearError: true);
    try {
      final code = await _api.getNextBatchCode();
      state = state.copyWith(nextBatchCode: code, isLoadingNextCode: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingNextCode: false,
        errorMessage: e.toString(),
      );
    }
  }
}

final duProvider = StateNotifierProvider<DUNotifier, DUState>((ref) {
  return DUNotifier(ref.watch(apiProvider));
});
