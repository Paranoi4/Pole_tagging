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
      // Next batch code for the first DU is computed by the screen once
      // both the DU list and the full batches list have loaded — see
      // updateNextBatchCode.
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void selectDU(DU du) {
    state = state.copyWith(selectedDU: du);
    // Next batch code is no longer computed here — the caller (the
    // screen) passes in the already-loaded batches list via
    // updateNextBatchCode, since this notifier has no access to
    // batchProvider's state.
  }

  // Computes the next batch code from a batches list the caller already
  // has loaded (e.g. batchProvider's full, unpaginated list), instead of
  // fetching a fresh, capped (limit=100) list from the server on every
  // DU switch.
  void updateNextBatchCode(DU du, List<Batch> allBatches) {
    state = state.copyWith(
      nextBatchCode: _getNextBatchCode(du, allBatches),
      isLoadingNextCode: false,
    );
  }

  // ✅ ADD THIS HELPER METHOD
  String _getNextBatchCode(DU du, List<Batch> existingBatches) {
    final year = DateTime.now().year;
    final prefix = 'BT-${du.duCode}-$year-';

    // Filter batches for this DU and year
    final yearBatches = existingBatches.where((batch) {
      return batch.duId == du.duId && batch.batchCode.startsWith(prefix);
    }).toList();

    // Next sequence number is the highest existing one + 1, not a count —
    // counting breaks the moment any batch is ever deleted, since the
    // count drops but the highest code already issued doesn't.
    final maxSeq = yearBatches.fold<int>(0, (max, batch) {
      final suffix = batch.batchCode.substring(prefix.length);
      final seq = int.tryParse(suffix) ?? 0;
      return seq > max ? seq : max;
    });

    final nextSeq = maxSeq + 1;
    return '$prefix${nextSeq.toString().padLeft(4, '0')}';
  }
}

// ============================================================
// PROVIDER
// ============================================================
final duProvider = StateNotifierProvider<DUNotifier, DUState>((ref) {
  return DUNotifier(ref.watch(apiProvider));
});
