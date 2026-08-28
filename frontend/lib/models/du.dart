// lib/models/du.dart
import 'package:frontend/helpers/parsing.dart';

class DU {
  final int duId;
  final String duName;
  final String duCode;
  final bool isActive;
  final DateTime? createdAt;
  final int? createdBy;

  DU({
    required this.duId,
    required this.duName,
    required this.duCode,
    this.isActive = true,
    this.createdAt,
    this.createdBy,
  });

  factory DU.fromJson(Map<String, dynamic> json) {
    return DU(
      duId: json['du_id'] ?? 0,
      duName: json['du_name'] ?? '',
      duCode: json['du_code'] ?? '',
      isActive: json['is_active'] ?? true,
      createdAt: parseServerDate(json['created_at']),
      createdBy: json['created_by'],
    );
  }

  String get displayName => '$duCode – $duName';
}
