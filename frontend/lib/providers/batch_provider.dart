// lib/providers/batch_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/batch.dart';
import 'package:frontend/services/api_services.dart';
import 'package:frontend/providers/api_providers.dart';

class BatchState {
  final bool isLoading;
  final String? errorMessage;
  final Batch? createdBatch;

  BatchState({
    this.isLoading = false,
    this.errorMessage,
    this.createdBatch,
  });

  factory BatchState.initial() {
    return BatchState(isLoading: false);
  }

  BatchState copyWith({
    bool? isLoading,
    String? errorMessage,
    Batch? createdBatch,
    bool clearError = false,
  }) {
    return BatchState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdBatch: createdBatch ?? this.createdBatch,
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
    int? assignedTo,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final batch = await _api.createBatch(
        duId: duId,
        workOrderId: workOrderId,
        quantity: quantity,
        assignedTo: assignedTo,
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

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final batchProvider = StateNotifierProvider<BatchNotifier, BatchState>((ref) {
  return BatchNotifier(ref.watch(apiProvider));
});
