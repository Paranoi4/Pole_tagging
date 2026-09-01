// lib/models/audit_entry.dart
import 'package:frontend/helpers/parsing.dart';

/// One line of the audit trail: a status change to a tag or a batch, who made
/// it, when, and why.
class AuditEntry {
  final int auditId;

  /// 'tag' or 'batch'.
  final String entityType;
  final int entityId;

  /// The code as it stood at the time — 'BT-N-2026-0048' or 'N31YF'. Null only
  /// on entries written before the server started recording it whose entity has
  /// since been deleted.
  final String? entityCode;

  /// Null on a creation (nothing before) or a deletion (nothing after).
  final String? fromStatus;
  final String? toStatus;

  final String? remarks;
  final DateTime? createdAt;
  final int? performedBy;

  /// Resolved server-side, so the trail reads as names rather than ids.
  final String? performedByName;

  AuditEntry({
    required this.auditId,
    required this.entityType,
    required this.entityId,
    this.entityCode,
    this.fromStatus,
    this.toStatus,
    this.remarks,
    this.createdAt,
    this.performedBy,
    this.performedByName,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        auditId: json['audit_id'] ?? 0,
        entityType: json['entity_type'] ?? '',
        entityId: json['entity_id'] ?? 0,
        entityCode: json['entity_code'],
        fromStatus: json['from_status'],
        toStatus: json['to_status'],
        remarks: json['remarks'],
        createdAt: parseServerDate(json['created_at']),
        performedBy: json['performed_by'],
        performedByName: json['performed_by_name'],
      );

  bool get isTag => entityType == 'tag';

  /// What kind of event this was, for the pill beside the code.
  ///
  /// Derived rather than stored: the statuses already say which action happened,
  /// so a separate column would be a second thing to keep in step with them.
  String get actionLabel {
    if (isTag) return 'Tag status';
    if (fromStatus == null) return 'Batch created';
    if (toStatus == null) return 'Batch deleted';
    if (fromStatus == 'Pending' && toStatus == 'Printed') return 'Print';
    if (toStatus == 'Dispatched') return 'Dispatch';
    if (fromStatus == 'Dispatched' && toStatus == 'Printed') return 'Return';
    return 'Batch status';
  }
}

/// A page of the trail plus the total behind it, so the header can state how
/// many events exist without a second request.
class AuditPage {
  final int total;
  final List<AuditEntry> items;

  AuditPage({required this.total, required this.items});

  factory AuditPage.fromJson(Map<String, dynamic> json) => AuditPage(
        total: json['total'] ?? 0,
        items: ((json['items'] as List<dynamic>?) ?? [])
            .map((e) => AuditEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
