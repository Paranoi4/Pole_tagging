// lib/models/work_order.dart
import 'package:frontend/helpers/parsing.dart';

class WorkOrder {
  final int workOrderId;
  final int duId;
  final String workOrderName;
  final String workOrderCode;
  final String? description;
  final DateTime? createdAt;
  final int? createdBy;

  WorkOrder({
    required this.workOrderId,
    required this.duId,
    required this.workOrderName,
    required this.workOrderCode,
    this.description,
    this.createdAt,
    this.createdBy,
  });

  factory WorkOrder.fromJson(Map<String, dynamic> json) {
    return WorkOrder(
      workOrderId: json['work_order_id'] ?? 0,
      duId: json['du_id'] ?? 0,
      workOrderName: json['work_order_name'] ?? '',
      workOrderCode: json['work_order_code'] ?? '',
      description: json['description'],
      createdAt: parseServerDate(json['created_at']),
      createdBy: json['created_by'],
    );
  }

  String get displayName => '$workOrderCode - $workOrderName';
}
