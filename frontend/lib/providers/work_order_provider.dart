// lib/providers/work_order_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/work_order.dart';
import 'package:frontend/services/api_services.dart';
import 'package:frontend/providers/api_providers.dart';

class WorkOrderState {
  final List<WorkOrder> workOrders;
  final bool isLoading;
  final String? errorMessage;
  final WorkOrder? selectedWorkOrder;

  WorkOrderState({
    required this.workOrders,
    required this.isLoading,
    this.errorMessage,
    this.selectedWorkOrder,
  });

  factory WorkOrderState.initial() {
    return WorkOrderState(
      workOrders: [],
      isLoading: false,
      errorMessage: null,
      selectedWorkOrder: null,
    );
  }

  WorkOrderState copyWith({
    List<WorkOrder>? workOrders,
    bool? isLoading,
    String? errorMessage,
    WorkOrder? selectedWorkOrder,
    bool clearError = false,
    bool clearSelectedWorkOrder = false,
  }) {
    return WorkOrderState(
      workOrders: workOrders ?? this.workOrders,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedWorkOrder: clearSelectedWorkOrder
          ? null
          : (selectedWorkOrder ?? this.selectedWorkOrder),
    );
  }
}

class WorkOrderNotifier extends StateNotifier<WorkOrderState> {
  final ApiService _api;

  WorkOrderNotifier(this._api) : super(WorkOrderState.initial());

  /// The query currently being fetched, so a duplicate of it can be dropped
  /// while a genuinely different one still gets through.
  String? _inFlightSearch;

  /// Loads work orders matching [search] — empty for the 20 most recent.
  ///
  /// No DU argument: an org owns one DU, so the server's org scoping already
  /// narrows it to the same rows.
  Future<void> searchWorkOrders({String search = ''}) async {
    // Drop a repeat of the search already in flight. Only an identical query is
    // skipped — a different one has to go through, or the type-ahead would
    // swallow keystrokes while an earlier request was still open.
    if (state.isLoading && search == _inFlightSearch) return;
    _inFlightSearch = search;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final workOrders = await _api.searchWorkOrders(search: search);
      // No auto-select. The selected work order is what `createBatch` bills
      // the batch to, so defaulting it to whichever row came back first lets a
      // printerman who never touched the field print against someone else's
      // work order — and it hid the "Please select a Work Order" guard, which
      // could never fire while the field filled itself in.
      state = state.copyWith(
        workOrders: workOrders,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Type-ahead lookup: returns the matches without storing them or moving the
  /// selection. Separate from [searchWorkOrders] because that one owns the
  /// dropdown's list, and letting every keystroke overwrite it would leave the
  /// list showing whatever the printerman last typed rather than the DU's work
  /// orders.
  Future<List<WorkOrder>> searchWorkOrderOptions(String search) {
    return _api.searchWorkOrders(search: search);
  }

  void selectWorkOrder(WorkOrder workOrder) {
    state = state.copyWith(selectedWorkOrder: workOrder);
  }

  /// Drops the selection — used when the DU changes, since a work order
  /// belongs to one DU and carrying it across would bill the batch to a DU the
  /// printerman is no longer looking at.
  void clearSelectedWorkOrder() {
    state = state.copyWith(clearSelectedWorkOrder: true);
  }
}

final workOrderProvider =
    StateNotifierProvider<WorkOrderNotifier, WorkOrderState>((ref) {
  return WorkOrderNotifier(ref.watch(apiProvider));
});
