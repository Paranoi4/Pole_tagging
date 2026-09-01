// lib/models/printerman_stats.dart

/// The batch behind the printerman's fourth stat card.
///
/// A trimmed batch, not the full [Batch] model: `/stats/printerman` sends only
/// what the tile prints, so there is no DU or work order to read here.
class CurrentBatchSummary {
  final int batchId;
  final String batchCode;
  final int quantity;
  final String status;

  const CurrentBatchSummary({
    required this.batchId,
    required this.batchCode,
    required this.quantity,
    required this.status,
  });

  factory CurrentBatchSummary.fromJson(Map<String, dynamic> json) {
    return CurrentBatchSummary(
      batchId: json['batch_id'] ?? 0,
      batchCode: json['batch_code'] ?? '',
      quantity: json['quantity'] ?? 0,
      status: json['status'] ?? '',
    );
  }
}

/// The four numbers across the top of the printerman screen, from
/// `GET /stats/printerman?du_id=`.
class PrintermanStats {
  final int duId;

  /// Organization-wide for this DU, not the signed-in printerman's own totals —
  /// the tag pool is shared, so "how many are left" is not a per-user question.
  final int totalPrinted;
  final int availableInPool;
  final int lostPrinted;

  /// The caller's own open batch. Null when they have none — the normal state
  /// before the first batch of a shift.
  final CurrentBatchSummary? currentBatch;

  const PrintermanStats({
    required this.duId,
    required this.totalPrinted,
    required this.availableInPool,
    required this.lostPrinted,
    this.currentBatch,
  });

  factory PrintermanStats.fromJson(Map<String, dynamic> json) {
    final batch = json['current_batch'];

    return PrintermanStats(
      duId: json['du_id'] ?? 0,
      totalPrinted: json['total_printed'] ?? 0,
      availableInPool: json['available_in_pool'] ?? 0,
      lostPrinted: json['lost_printed'] ?? 0,
      currentBatch: batch == null
          ? null
          : CurrentBatchSummary.fromJson(batch as Map<String, dynamic>),
    );
  }
}
