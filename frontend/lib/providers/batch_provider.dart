// lib/providers/batch_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/batch.dart';
import 'package:frontend/services/api_services.dart';
import 'package:frontend/providers/api_providers.dart';

class BatchState {
  final bool isLoading;
  final String? errorMessage;
  final Batch? createdBatch;
  final List<Batch> batches; // new

  /// The batch the signed-in printerman created and has not finished printing.
  /// Null is a real value here — it means "this printerman has no open batch" —
  /// so clearing it goes through [copyWith]'s `clearCurrentBatch` flag rather
  /// than passing null, which `??` would read as "leave it alone".
  final Batch? currentBatch;

  BatchState({
    this.isLoading = false,
    this.errorMessage,
    this.createdBatch,
    this.batches = const [], // new
    this.currentBatch,
  });

  factory BatchState.initial() {
    return BatchState(isLoading: false);
  }

  BatchState copyWith({
    bool? isLoading,
    String? errorMessage,
    Batch? createdBatch,
    bool clearError = false,
    List<Batch>? batches, // new
    Batch? currentBatch,
    bool clearCurrentBatch = false,
  }) {
    return BatchState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdBatch: createdBatch ?? this.createdBatch,
      batches: batches ?? this.batches, // new
      currentBatch:
          clearCurrentBatch ? null : (currentBatch ?? this.currentBatch),
    );
  }
}

class BatchNotifier extends StateNotifier<BatchState> {
  final ApiService _api;

  BatchNotifier(this._api) : super(BatchState.initial());

  Future<Batch> createBatch({
    required int duId,
    required int workOrderId,
    required int quantity,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final batch = await _api.createBatch(
        duId: duId,
        workOrderId: workOrderId,
        quantity: quantity,
      );
      state = state.copyWith(
        isLoading: false,
        createdBatch: batch,
      );
      return batch;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// GET /batches/my-current — the caller's own unprinted batch, or null.
  ///
  /// Deliberately does not touch `isLoading`: the create-batch button watches
  /// that flag, and this runs from a build-time guard, so flipping it here
  /// would spin that button every time the screen rebuilds. The screen keeps
  /// its own re-entry guard for this call.
  Future<Batch?> loadMyCurrentBatch() async {
    try {
      final batch = await _api.getMyCurrentBatch();
      state = batch == null
          ? state.copyWith(clearCurrentBatch: true)
          : state.copyWith(currentBatch: batch);
      return batch;
    } catch (e) {
      // A printerman with no open batch is the normal empty state, not an
      // error worth showing, so the message is left unset — but the stale
      // batch still has to go.
      state = state.copyWith(clearCurrentBatch: true);
      rethrow;
    }
  }

  /// PATCH /batches/{id}/status — returns the saved row, so the fresh batch
  /// comes back from the call that changed it rather than needing a GET.
  Future<Batch> updateBatchStatus(int batchId, String status) async {
    final updated = await _api.updateBatchStatus(batchId, status);

    state = state.copyWith(
      currentBatch:
          state.currentBatch?.batchId == batchId ? updated : state.currentBatch,
      batches: state.batches
          .map((b) => b.batchId == batchId ? updated : b)
          .toList(),
    );
    return updated;
  }

  Future<void> loadAllBatches() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final batches = await _api.getAllBatches();
      state = state.copyWith(batches: batches, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final batchProvider = StateNotifierProvider<BatchNotifier, BatchState>((ref) {
  return BatchNotifier(ref.watch(apiProvider));
});
