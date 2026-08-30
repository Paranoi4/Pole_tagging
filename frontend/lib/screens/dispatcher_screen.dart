// 📁 lib/screens/dispatcher_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/providers/auth_providers.dart';
import 'package:frontend/models/batch.dart';
import 'package:frontend/models/tag.dart';
import 'package:frontend/providers/batch_provider.dart';
import 'package:frontend/providers/api_providers.dart';

class DispatcherScreen extends ConsumerStatefulWidget {
  final bool showPrintermanShortcut;

  const DispatcherScreen({super.key, this.showPrintermanShortcut = false});

  @override
  ConsumerState<DispatcherScreen> createState() => _DispatcherScreenState();
}

class _DispatcherScreenState extends ConsumerState<DispatcherScreen> {
  int selectedBatchIndex = 0;
  final ScrollController _tagListScrollController = ScrollController();

  // Real tag data for whichever batch is selected.
  List<Tag> _selectedBatchTags = [];
  bool _isLoadingTags = false;
  int? _tagsLoadedForBatchId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(batchProvider.notifier).loadAllBatches();
    });
  }

  @override
  void dispose() {
    _tagListScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTagsForBatch(int batchId) async {
    if (_tagsLoadedForBatchId == batchId) return; // already have it
    if (_isLoadingTags) return; // ✅ ADD THIS — stops the rebuild storm
    setState(() => _isLoadingTags = true);
    try {
      final tags = await ref.read(apiProvider).getBatchTags(batchId);
      if (mounted) {
        setState(() {
          _selectedBatchTags = tags;
          _isLoadingTags = false;
          _tagsLoadedForBatchId = batchId;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTags = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final batchState = ref.watch(batchProvider);
    final availableBatches = batchState.batches
        .where((b) => b.status == 'Printed' && b.assignedTo == null)
        .toList();

    final hasBatches = availableBatches.isNotEmpty;
    if (selectedBatchIndex >= availableBatches.length) selectedBatchIndex = 0;
    final Batch? selectedBatch =
        hasBatches ? availableBatches[selectedBatchIndex] : null;

    // Whenever the selected batch changes, fetch its real tags.
    // _loadTagsForBatch bails out early if we already have this batch's
    // tags, so this is safe to call on every build.
    if (selectedBatch != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadTagsForBatch(selectedBatch.batchId);
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Dispatcher',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: false,
        actions: [
          if (widget.showPrintermanShortcut)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Printerman',
              onPressed: () => context.go('/printerman'),
            ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ============================================================
                // STAT CARDS
                // ============================================================
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'READY TO DISPATCH',
                          '11',
                          'printed tags on hand',
                          valueColor: const Color(0xFF1A7A3D),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'OPEN BATCHES',
                          '${availableBatches.length}',
                          'awaiting assignment',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'DISPATCHED',
                          '9',
                          'tags with field crew',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSelectedBatchCard(
                          selectedBatch?.batchCode ?? '—',
                          hasBatches
                              ? '${selectedBatch!.quantity} tags · available'
                              : 'No batch selected',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ============================================================
                // MAIN CONTENT: Printed batches + Batch detail
                // ============================================================
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ---------------- LEFT: Printed batches ----------------
                      Expanded(
                        flex: 5,
                        child: _panelContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Printed batches',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Select a batch to dispatch',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (batchState.isLoading)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                )
                              else if (!hasBatches)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 40),
                                  child: Center(
                                    child: Text(
                                      'No batches ready to dispatch',
                                      style: TextStyle(color: Colors.grey[500]),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Table header
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          border: Border(
                                            bottom: BorderSide(
                                                color: Colors.grey[300]!),
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(8),
                                            topRight: Radius.circular(8),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            _buildTableHeader('BATCH ID',
                                                flex: 4),
                                            _buildTableHeader('QTY',
                                                flex: 1,
                                                alignment: TextAlign.right),
                                            _buildTableHeader('STATUS',
                                                flex: 2,
                                                alignment: TextAlign.right),
                                          ],
                                        ),
                                      ),
                                      // Table rows
                                      ...availableBatches
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        final i = entry.key;
                                        final batch = entry.value;
                                        final isSelected =
                                            i == selectedBatchIndex;
                                        return InkWell(
                                          onTap: () {
                                            setState(
                                                () => selectedBatchIndex = i);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(0xFFF0FAF3)
                                                  : Colors.transparent,
                                              border: Border(
                                                left: BorderSide(
                                                  color: isSelected
                                                      ? const Color(0xFF1A7A3D)
                                                      : Colors.transparent,
                                                  width: 3,
                                                ),
                                                bottom: BorderSide(
                                                    color: Colors.grey[200]!),
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  flex: 4,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        batch.batchCode,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'DU #${batch.duId} · unassigned',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[500],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 1,
                                                  child: Text(
                                                    '${batch.quantity}',
                                                    textAlign: TextAlign.right,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: _buildStatusPill(
                                                      'Available',
                                                      const Color(0xFF1A7A3D),
                                                      const Color(0xFFE7F6EC),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // ---------------- RIGHT: Batch detail ----------------
                      Expanded(
                        flex: 6,
                        child: _panelContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selectedBatch?.batchCode ??
                                              'No batch selected',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          hasBatches
                                              ? 'DU #${selectedBatch!.duId} · available'
                                              : '',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'QUANTITY',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[500],
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        hasBatches
                                            ? '${selectedBatch!.quantity}'
                                            : '—',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Step indicator
                              Row(
                                children: [
                                  _buildStep('1', 'Confirm quantity',
                                      isActive: true),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      color: Colors.grey[300],
                                    ),
                                  ),
                                  _buildStep('2', 'Dispatch to crew',
                                      isActive: false),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Tag table — now real data
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        border: Border(
                                          bottom: BorderSide(
                                              color: Colors.grey[300]!),
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(8),
                                          topRight: Radius.circular(8),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          _buildTableHeader('#', flex: 1),
                                          _buildTableHeader('TAG ID', flex: 3),
                                          _buildTableHeader('POLE NO.',
                                              flex: 3),
                                          _buildTableHeader('STATUS',
                                              flex: 2,
                                              alignment: TextAlign.right),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      height: 300,
                                      child: _isLoadingTags
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          : _selectedBatchTags.isEmpty
                                              ? Center(
                                                  child: Text(
                                                    'No tags in this batch',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[500]),
                                                  ),
                                                )
                                              : Scrollbar(
                                                  controller:
                                                      _tagListScrollController,
                                                  thumbVisibility: true,
                                                  child: SingleChildScrollView(
                                                    controller:
                                                        _tagListScrollController,
                                                    child: Column(
                                                      children:
                                                          _selectedBatchTags
                                                              .asMap()
                                                              .entries
                                                              .map((entry) {
                                                        final index = entry.key;
                                                        final tag = entry.value;
                                                        return Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 16,
                                                            vertical: 12,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            border: Border(
                                                              bottom: BorderSide(
                                                                  color: Colors
                                                                          .grey[
                                                                      200]!),
                                                            ),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Expanded(
                                                                flex: 1,
                                                                child: Text(
                                                                  '${index + 1}',
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          13),
                                                                ),
                                                              ),
                                                              Expanded(
                                                                flex: 3,
                                                                child: Text(
                                                                  tag.tagCode,
                                                                  style:
                                                                      const TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                              ),
                                                              Expanded(
                                                                flex: 3,
                                                                child: Text(
                                                                  tag.poleNo,
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          13),
                                                                ),
                                                              ),
                                                              Expanded(
                                                                flex: 2,
                                                                child: Align(
                                                                  alignment:
                                                                      Alignment
                                                                          .centerRight,
                                                                  child:
                                                                      _buildStatusPill(
                                                                    tag.status,
                                                                    const Color(
                                                                        0xFF1A7A3D),
                                                                    const Color(
                                                                        0xFFE7F6EC),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ),
                                                ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Footer: note + confirm button
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      hasBatches
                                          ? 'Count the sheet against the ${_selectedBatchTags.length} tag IDs listed above.'
                                          : 'Select a batch to begin.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1A7A3D),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Confirm quantity'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helper Widgets ───

  Widget _panelContainer({required Widget child}) {
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String subtitle, {
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedBatchCard(String batchId, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0B2A1B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECTED BATCH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey[400],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            batchId,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(
    String text, {
    int flex = 1,
    TextAlign alignment = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: alignment,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusPill(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildStep(String number, String label, {required bool isActive}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor:
              isActive ? const Color(0xFF1A7A3D) : Colors.grey[300],
          child: Text(
            number,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? const Color(0xFF1A7A3D) : Colors.grey[500],
          ),
        ),
      ],
    );
  }
}
