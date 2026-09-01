// lib/providers/tag_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/tag.dart';
import 'package:frontend/services/api_services.dart';
import 'package:frontend/providers/api_providers.dart';

class TagState {
  final List<Tag> tags;

  /// Which batch [tags] belongs to. Held alongside the list so a reader can
  /// tell a loaded-but-empty batch from tags left over from a different one.
  final int? batchId;

  final bool isLoading;
  final String? errorMessage;

  TagState({
    this.tags = const [],
    this.batchId,
    this.isLoading = false,
    this.errorMessage,
  });

  factory TagState.initial() => TagState();

  TagState copyWith({
    List<Tag>? tags,
    int? batchId,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TagState(
      tags: tags ?? this.tags,
      batchId: batchId ?? this.batchId,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class TagNotifier extends StateNotifier<TagState> {
  final ApiService _api;

  TagNotifier(this._api) : super(TagState.initial());

  /// GET /batches/{id}/tags. Returns the rows as well as storing them, because
  /// the print sheet hands the same fetch to the screen behind it rather than
  /// letting both read the batch separately.
  Future<List<Tag>> loadBatchTags(int batchId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final tags = await _api.getBatchTags(batchId);
      state = state.copyWith(tags: tags, batchId: batchId, isLoading: false);
      return tags;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// PATCH /tags/bulk/status — one call per set of tags, not one per tag.
  ///
  /// Does not refresh [state.tags] itself: every caller re-reads the batch
  /// immediately afterwards to pick up whatever else the server changed, and
  /// refreshing here would make that two GETs instead of one.
  Future<void> bulkUpdateStatus(
    List<int> tagIds,
    String status, {
    String? remarks,
  }) async {
    try {
      await _api.bulkUpdateTagStatus(tagIds, status, remarks: remarks);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final tagProvider = StateNotifierProvider<TagNotifier, TagState>((ref) {
  return TagNotifier(ref.watch(apiProvider));
});
