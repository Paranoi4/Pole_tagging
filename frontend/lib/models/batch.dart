// lib/models/batch.dart
import 'package:frontend/helpers/parsing.dart';
import 'package:frontend/models/work_order.dart';

class Batch {
  final int batchId;
  final int duId;
  final int? workOrderId;
  final String batchCode;
  final int quantity;
  final String status;
  /// The crew this batch was dispatched to, null until it is handed over.
  final int? assignedCrewId;

  /// The staff member who released it, null until then.
  final int? dispatchedBy;

  /// When it was handed over, null until then.
  final DateTime? dispatchedAt;
  final DateTime? createdAt;
  final int? createdBy;

  /// The work order this batch belongs to. Already nested in every BatchOut, so
  /// reading it here costs nothing extra — it saves a lookup per batch wherever
  /// the work order code has to be shown alongside a batch.
  final WorkOrder? workOrder;

  Batch({
    required this.batchId,
    required this.duId,
    this.workOrderId,
    required this.batchCode,
    required this.quantity,
    required this.status,
    this.assignedCrewId,
    this.dispatchedBy,
    this.dispatchedAt,
    this.createdAt,
    this.createdBy,
    this.workOrder,
  });

  factory Batch.fromJson(Map<String, dynamic> json) {
    return Batch(
      batchId: json['batch_id'] ?? 0,
      duId: json['du_id'] ?? 0,
      workOrderId: json['work_order_id'],
      batchCode: json['batch_code'] ?? '',
      quantity: json['quantity'] ?? 0,
      status: json['status'] ?? 'Pending',
      assignedCrewId: json['assigned_crew_id'],
      dispatchedBy: json['dispatched_by'],
      dispatchedAt: parseServerDate(json['dispatched_at']),
      createdAt: parseServerDate(json['created_at']),
      createdBy: json['created_by'],
      workOrder: json['work_order'] != null
          ? WorkOrder.fromJson(json['work_order'] as Map<String, dynamic>)
          : null,
    );
  }
}
