// lib/models/batch.dart
import 'package:frontend/helpers/parsing.dart';

class Batch {
  final int batchId;
  final int duId;
  final int? workOrderId;
  final String batchCode;
  final int quantity;
  final String status;
  final int? assignedTo;
  final DateTime? createdAt;
  final int? createdBy;

  Batch({
    required this.batchId,
    required this.duId,
    this.workOrderId,
    required this.batchCode,
    required this.quantity,
    required this.status,
    this.assignedTo,
    this.createdAt,
    this.createdBy,
  });

  factory Batch.fromJson(Map<String, dynamic> json) {
    return Batch(
      batchId: json['batch_id'] ?? 0,
      duId: json['du_id'] ?? 0,
      workOrderId: json['work_order_id'],
      batchCode: json['batch_code'] ?? '',
      quantity: json['quantity'] ?? 0,
      status: json['status'] ?? 'Pending',
      assignedTo: json['assigned_to'],
      createdAt: parseServerDate(json['created_at']),
      createdBy: json['created_by'],
    );
  }
}
