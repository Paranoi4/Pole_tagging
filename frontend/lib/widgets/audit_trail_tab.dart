// 📁 lib/widgets/audit_trail_tab.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/audit_entry.dart';
import 'package:frontend/providers/api_providers.dart';

/// The admin's audit trail: every status change to a tag or batch in their
/// organization, newest first.
///
/// Paged rather than loaded whole. This is the fastest-growing table in the
/// schema — printing one batch writes an entry per tag — so pulling it all would
/// get slower every day the system runs.
class AuditTrailTab extends ConsumerStatefulWidget {
  const AuditTrailTab({super.key});

  @override
  ConsumerState<AuditTrailTab> createState() => _AuditTrailTabState();
}

class _AuditTrailTabState extends ConsumerState<AuditTrailTab> {
  static const _pageSize = 50;

  final TextEditingController _searchController = TextEditingController();
  final List<AuditEntry> _entries = [];

  int _total = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  /// null = everything, otherwise 'tag' or 'batch'.
  String? _entityType;

  String _search = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Fresh first page. [_loadMore] appends instead.
  Future<void> _load() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final page = await ref.read(apiProvider).getAuditLog(
            limit: _pageSize,
            search: _search.isEmpty ? null : _search,
            entityType: _entityType,
          );
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(page.items);
        _total = page.total;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _entries.length >= _total) return;
    setState(() => _isLoadingMore = true);

    try {
      final page = await ref.read(apiProvider).getAuditLog(
            skip: _entries.length,
            limit: _pageSize,
            search: _search.isEmpty ? null : _search,
            entityType: _entityType,
          );
      if (!mounted) return;
      setState(() {
        _entries.addAll(page.items);
        _total = page.total;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load more: $e')),
      );
    }
  }

  /// Debounced so typing does not fire a request per keystroke — each one is a
  /// round trip, and the server searches four columns plus a join.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || value == _search) return;
      _search = value.trim();
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _buildError()
          else if (_entries.isEmpty)
            _buildEmpty()
          else
            _buildList(),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Audit trail',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              _total == 0
                  ? 'No events recorded yet'
                  : '$_total ${_total == 1 ? "event" : "events"} recorded '
                      'across print, dispatch and admin actions',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Filter by tag ID, batch, person…',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey[500]),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            _search = '';
                            _load();
                          },
                        ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _buildActivityFilter(),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityFilter() {
    const options = <String?, String>{
      null: 'All activity',
      'tag': 'Tag activity',
      'batch': 'Batch activity',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _entityType,
          isDense: true,
          items: options.entries
              .map((e) => DropdownMenuItem<String?>(
                    value: e.key,
                    child: Text(e.value, style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() => _entityType = value);
            _load();
          },
        ),
      ),
    );
  }

  // ─── States ───────────────────────────────────────────────────────

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(fontSize: 12, color: Colors.red[800]),
            ),
          ),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final filtered = _search.isNotEmpty || _entityType != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Text(
          filtered
              ? 'No events match this filter.'
              : 'No events recorded yet. Printing, dispatching and status '
                  'changes will appear here.',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
      ),
    );
  }

  // ─── The trail ────────────────────────────────────────────────────

  Widget _buildList() {
    // Grouped by day, so a long trail reads as "today, then yesterday" rather
    // than one undifferentiated wall of timestamps.
    final groups = <String, List<AuditEntry>>{};
    for (final e in _entries) {
      groups.putIfAbsent(_dayLabel(e.createdAt), () => []).add(e);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              for (final entry in groups.entries) ...[
                _buildDayHeader(entry.key),
                for (final e in entry.value) _buildRow(e),
              ],
            ],
          ),
        ),
        if (_entries.length < _total) ...[
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(
              onPressed: _isLoadingMore ? null : _loadMore,
              child: _isLoadingMore
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Load more (${_total - _entries.length} left)'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDayHeader(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildRow(AuditEntry e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              _timeLabel(e.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          SizedBox(
            width: 132,
            child: Text(
              e.entityCode ?? '—',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
          SizedBox(width: 108, child: _actionPill(e)),
          const SizedBox(width: 12),
          // The change itself. A creation or deletion has only one side, so it
          // reads as a single label rather than an arrow from nothing.
          Expanded(
            flex: 3,
            child: _buildChange(e),
          ),
          Expanded(
            flex: 3,
            child: Text(
              e.remarks ?? '',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              e.performedByName ?? 'account removed',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: e.performedByName == null
                    ? Colors.grey[400]
                    : Colors.grey[800],
                fontStyle:
                    e.performedByName == null ? FontStyle.italic : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChange(AuditEntry e) {
    if (e.fromStatus == null && e.toStatus != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: _statusChip(e.toStatus!),
      );
    }
    if (e.toStatus == null && e.fromStatus != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statusChip(e.fromStatus!),
          const SizedBox(width: 6),
          Text('removed',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      );
    }
    if (e.fromStatus == null && e.toStatus == null) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _statusChip(e.fromStatus!),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward, size: 13, color: Colors.grey[500]),
        ),
        _statusChip(e.toStatus!),
      ],
    );
  }

  // ─── Small pieces ─────────────────────────────────────────────────

  Widget _actionPill(AuditEntry e) {
    final label = e.actionLabel;
    Color color;
    switch (label) {
      case 'Print':
        color = Colors.blue;
        break;
      case 'Dispatch':
        color = Colors.orange[800]!;
        break;
      case 'Return':
        color = Colors.teal;
        break;
      case 'Batch created':
        color = const Color(0xFF1A7A3D);
        break;
      case 'Batch deleted':
        color = Colors.red;
        break;
      default:
        color = Colors.blueGrey;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }

  /// Same colour language as the tag tables elsewhere, so a status means the
  /// same thing wherever it appears.
  Widget _statusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'available':
        color = const Color(0xFF1A7A3D);
        break;
      case 'printed':
        color = Colors.blue;
        break;
      case 'pending':
        color = Colors.amber[800]!;
        break;
      case 'dispatched':
        color = Colors.orange[800]!;
        break;
      case 'installed':
        color = Colors.purple;
        break;
      case 'jam paper':
        color = Colors.deepOrange;
        break;
      case 'lost printed':
      case 'damaged':
        color = Colors.red;
        break;
      case 'do not use':
        color = Colors.blueGrey;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  String _dayLabel(DateTime? at) {
    if (at == null) return 'Unknown date';
    final local = at.toLocal();
    final today = DateTime.now();
    final day = DateTime(local.year, local.month, local.day);
    final t = DateTime(today.year, today.month, today.day);
    final diff = t.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _timeLabel(DateTime? at) {
    if (at == null) return '—';
    final local = at.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour < 12 ? "AM" : "PM"}';
  }
}
