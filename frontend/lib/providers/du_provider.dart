// lib/providers/du_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/du.dart';
import 'package:frontend/models/batch.dart'; // ✅ ADD THIS IMPORT
import 'package:frontend/services/api_services.dart';
import 'package:frontend/providers/api_providers.dart';

// ============================================================
// STATE
// ============================================================
class DUState {
  final List<DU> dus;
  final bool isLoading;
  final String? errorMessage;
  final DU? selectedDU;
  final String? nextBatchCode; // ✅ ADD THIS
  final bool isLoadingNextCode; // ✅ ADD THIS

  DUState({
    required this.dus,
    required this.isLoading,
    this.errorMessage,
    this.selectedDU,
    this.nextBatchCode, // ✅ ADD THIS
    this.isLoadingNextCode = false, // ✅ ADD THIS
  });

  factory DUState.initial() {
    return DUState(
      dus: [],
      isLoading: false,
      errorMessage: null,
      selectedDU: null,
      nextBatchCode: null, // ✅ ADD THIS
      isLoadingNextCode: false, // ✅ ADD THIS
    );
  }

  DUState copyWith({
    List<DU>? dus,
    bool? isLoading,
    String? errorMessage,
    DU? selectedDU,
    String? nextBatchCode, // ✅ ADD THIS
    bool? isLoadingNextCode, // ✅ ADD THIS
    bool clearError = false,
  }) {
    return DUState(
      dus: dus ?? this.dus,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedDU: selectedDU ?? this.selectedDU,
      nextBatchCode: nextBatchCode ?? this.nextBatchCode, // ✅ ADD THIS
      isLoadingNextCode:
          isLoadingNextCode ?? this.isLoadingNextCode, // ✅ ADD THIS
    );
  }
}

// ============================================================
// NOTIFIER
// ============================================================
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

      // ✅ Auto-load next batch code for first DU
      if (dus.isNotEmpty) {
        await loadNextBatchCode(dus.first);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void selectDU(DU du) {
    state = state.copyWith(selectedDU: du);
    // ✅ Load next batch code when DU changes
    loadNextBatchCode(du);
  }

  // ✅ ADD THIS METHOD - Load next batch code
  Future<void> loadNextBatchCode(DU du) async {
    state = state.copyWith(isLoadingNextCode: true);

    try {
      final batches = await _api.getBatchesForDU(du.duId);
      final nextCode = _getNextBatchCode(du, batches);
      state = state.copyWith(
        nextBatchCode: nextCode,
        isLoadingNextCode: false,
      );
    } catch (e) {
      state = state.copyWith(
        nextBatchCode: 'Error loading',
        isLoadingNextCode: false,
      );
    }
  }

  // ✅ ADD THIS HELPER METHOD
  String _getNextBatchCode(DU du, List<Batch> existingBatches) {
    final year = DateTime.now().year;

    // Filter batches for this DU and year
    final yearBatches = existingBatches.where((batch) {
      return batch.duId == du.duId && batch.batchCode.contains('-$year-');
    }).toList();

    // Calculate next sequence number
    final nextSeq = yearBatches.length + 1;

    return 'BT-${du.duCode}-$year-${nextSeq.toString().padLeft(4, '0')}';
  }
}

// ============================================================
// PROVIDER
// ============================================================
final duProvider = StateNotifierProvider<DUNotifier, DUState>((ref) {
  return DUNotifier(ref.watch(apiProvider));
});
