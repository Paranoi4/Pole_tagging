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
  }) {
    return WorkOrderState(
      workOrders: workOrders ?? this.workOrders,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedWorkOrder: selectedWorkOrder ?? this.selectedWorkOrder,
    );
  }
}

class WorkOrderNotifier extends StateNotifier<WorkOrderState> {
  final ApiService _api;

  WorkOrderNotifier(this._api) : super(WorkOrderState.initial());

  Future<void> loadWorkOrdersForDU(int duId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final workOrders = await _api.getWorkOrdersForDU(duId);
      state = state.copyWith(
        workOrders: workOrders,
        isLoading: false,
        selectedWorkOrder: workOrders.isNotEmpty ? workOrders.first : null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void selectWorkOrder(WorkOrder workOrder) {
    state = state.copyWith(selectedWorkOrder: workOrder);
  }
}

final workOrderProvider =
    StateNotifierProvider<WorkOrderNotifier, WorkOrderState>((ref) {
  return WorkOrderNotifier(ref.watch(apiProvider));
});
