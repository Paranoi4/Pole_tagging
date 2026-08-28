// lib/models/tag.dart
import 'package:frontend/helpers/parsing.dart';

class Tag {
  final int tagId;
  final int duId;
  final int? batchId;
  final String tagCode;
  final String poleNo;
  final String status;
  final String? remarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? createdBy;
  final int? updatedBy;

  Tag({
    required this.tagId,
    required this.duId,
    this.batchId,
    required this.tagCode,
    required this.poleNo,
    required this.status,
    this.remarks,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      tagId: json['tag_id'] ?? 0,
      duId: json['du_id'] ?? 0,
      batchId: json['batch_id'],
      tagCode: json['tag_code'] ?? '',
      poleNo: json['pole_no'] ?? '',
      status: json['status'] ?? 'Available',
      remarks: json['remarks'],
      createdAt: parseServerDate(json['created_at']),
      updatedAt: parseServerDate(json['updated_at']),
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
    );
  }
}
