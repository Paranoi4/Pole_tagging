// 📁 lib/screens/printerman_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/config/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/providers/auth_providers.dart';
import 'package:frontend/providers/du_provider.dart';
import 'package:frontend/models/du.dart';
import 'package:frontend/providers/work_order_provider.dart';
import 'package:frontend/models/work_order.dart';
import 'package:frontend/providers/batch_provider.dart';
import 'package:frontend/providers/tag_provider.dart';
import 'package:frontend/providers/stats_provider.dart';
import 'package:frontend/helpers/formatting.dart';
import 'package:frontend/models/batch.dart';
import 'package:frontend/models/tag.dart';
import 'package:frontend/widgets/stat_card.dart';
import 'package:frontend/services/tag_sheet_pdf.dart';
import 'package:printing/printing.dart';

class PrinterManScreen extends ConsumerStatefulWidget {
  const PrinterManScreen({super.key});

  @override
  ConsumerState<PrinterManScreen> createState() => _PrinterManScreenState();
}

class _PrinterManScreenState extends ConsumerState<PrinterManScreen> {
  // Form state
  DU? _selectedDU;
  WorkOrder? _selectedWorkOrder;
  String? _selectedWorkOrderId;
  int _quantity = 24;
  bool _isGenerating = false;

  // Current batch state
  Batch? _currentBatch;
  List<Tag>? _currentBatchTags;
  bool _isLoadingBatch = false;
  bool _isLoadingMyBatch = false;
  DU? _nextCodeDU;
  final TextEditingController _workOrderController = TextEditingController();
  final FocusNode _workOrderFocus = FocusNode();
  String _workOrderQuery = '';

  @override
  void dispose() {
    _workOrderController.dispose();
    _workOrderFocus.dispose();
    super.dispose();
  }

  Future<Iterable<WorkOrder>> _searchWorkOrderOptions(String query) async {
    // Nothing typed yet — an empty field means the printerman has only clicked
    // in, so there is nothing to look up.
    if (query.isEmpty) return const <WorkOrder>[];

    _workOrderQuery = query;
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted || _workOrderQuery != query) return const <WorkOrder>[];

    try {
      return await ref
          .read(workOrderProvider.notifier)
          .searchWorkOrderOptions(query);
    } catch (_) {
      return const <WorkOrder>[];
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(duProvider.notifier).loadDUs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final duState = ref.watch(duProvider);
    final workOrderState = ref.watch(workOrderProvider);
    final stats = ref.watch(printermanStatsProvider).stats;

    // Sync selected DU with provider state
    if (duState.selectedDU != null && _selectedDU != duState.selectedDU) {
      _selectedDU = duState.selectedDU;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadMyCurrentBatch();
        ref.read(printermanStatsProvider.notifier).load(_selectedDU!.duId);
      });
    }
    if (_selectedDU != null && _nextCodeDU != _selectedDU) {
      _nextCodeDU = _selectedDU;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(duProvider.notifier).loadNextBatchCode();
      });
    }

    if (workOrderState.selectedWorkOrder != null &&
        _selectedWorkOrder != workOrderState.selectedWorkOrder) {
      _selectedWorkOrder = workOrderState.selectedWorkOrder;
      final label = _selectedWorkOrder!.displayName;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _workOrderFocus.hasFocus) return;
        if (_workOrderController.text != label) {
          _workOrderController.text = label;
        }
      });
    }


    final bool canPrint = _currentBatch != null && (_currentBatchTags?.isNotEmpty ?? false);
    final showDispatcherShortcut = ref.watch(authProvider).user?.roles.any((role) => role.roleName == 'Dispatcher') ??false;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        title: const Text(
          'Pole Tagging',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 1,
        centerTitle: false,
        actions: [
          if (showDispatcherShortcut)
            IconButton(
              icon: const Icon(Icons.local_shipping),
              tooltip: 'Dispatcher',
              onPressed: () => context.go('/dispatcher'),
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
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'TOTAL PRINTED',
                        // An em dash until the first load lands: a placeholder
                        // 0 would read as a real count of nothing printed.
                        value: stats == null
                            ? '—'
                            : formatCount(stats.totalPrinted),
                        subtitle: 'tag IDs printed all-time',
                        icon: Icons.print,
                        iconColor: AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        label: 'AVAILABLE IN POOL',
                        value: stats == null
                            ? '—'
                            : formatCount(stats.availableInPool),
                        subtitle: 'unassigned tag IDs',
                        icon: Icons.inventory_2,
                        iconColor: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        label: 'LOST PRINTED',
                        value: stats == null
                            ? '—'
                            : formatCount(stats.lostPrinted),
                        subtitle: 'awaiting reprint',
                        icon: Icons.warning_amber_rounded,
                        iconColor: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        label: 'THIS BATCH QUANTITY',
                        // The batch's own count, not `_quantity`: that field is
                        // the number typed into the form for the *next* batch,
                        // so the tile used to contradict its own subtitle.
                        value: _currentBatch != null
                            ? formatCount(_currentBatch!.quantity)
                            : '—',
                        subtitle: _currentBatch != null
                            ? '${_currentBatch!.batchCode} - ${_currentBatch!.quantity} tags'
                            : 'no batch awaiting print',
                        icon: Icons.production_quantity_limits,
                        iconColor: AppColors.accent,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ============================================================
                // NEW PRINT BATCH
                // ============================================================
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New print batch',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDisabled,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDUField(duState),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildBatchField(
                              'BATCH ID',
                              duState.isLoadingNextCode
                                  ? 'Calculating...'
                                  : (duState.nextBatchCode ?? 'Select DU'),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildWorkOrderField(workOrderState),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildQuantityField(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 160,
                          child: ElevatedButton(
                            onPressed: _isGenerating ||
                                    duState.isLoading ||
                                    workOrderState.isLoading
                                ? null
                                : _generateBatch,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: AppColors.onBrand,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isGenerating
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.onBrand,
                                    ),
                                  )
                                : const Text('Generate batch'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ============================================================
                // CURRENT BATCH - WITH PRINT BUTTON
                // ============================================================
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Header ──────────────────────────────────────────
                      Row(
                        children: [
                          const Text(
                            'Current batch',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (_currentBatch != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _currentBatch!.status.toLowerCase() ==
                                        'pending'
                                    ? AppColors.warningBg
                                    : AppColors.successBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _currentBatch!.status.toLowerCase() ==
                                          'pending'
                                      ? AppColors.warningBorder
                                      : AppColors.successBorder,
                                ),
                              ),
                              child: Text(
                                '${_currentBatch!.batchCode} - ${_currentBatch!.quantity} tags - ${_currentBatch!.status}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _currentBatch!.status.toLowerCase() ==
                                          'pending'
                                      ? AppColors.warningText
                                      : AppColors.successText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderStrong),
                              ),
                              child: Text(
                                'No batch generated yet',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          const Spacer(),
                          // ✅ PRINT TAGS BUTTON
                          if (canPrint)
                            ElevatedButton.icon(
                              onPressed: () => _showPrintModal(
                                  _currentBatch!, _currentBatchTags!),
                              icon: const Icon(Icons.print, size: 18),
                              label: const Text('Print tags'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                foregroundColor: AppColors.onBrand,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ─── Table ──────────────────────────────────────────
                      if (_isLoadingBatch)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_currentBatchTags != null &&
                          _currentBatchTags!.isNotEmpty)
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderStrong),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Table Header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppColors.borderStrong,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _buildTableHeader('#', flex: 1),
                                    _buildTableHeader('TAG ID', flex: 3),
                                    _buildTableHeader('POLE NO.', flex: 3),
                                    _buildTableHeader('STATUS',
                                        flex: 2), // ← Reduced from 3 to 2
                                    _buildTableHeader('REMARKS',
                                        flex: 2), // ← Reduced from 3 to 2
                                    const SizedBox(
                                      width: 120, // ← Reduced from 140 to 120
                                      child: Text(
                                        'ACTION',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.scrim,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Table Rows - FROM API
                              ..._currentBatchTags!
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final index = entry.key;
                                final tag = entry.value;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: AppColors.border,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildTableCell('${index + 1}', flex: 1),
                                      _buildTableCell(tag.tagCode,
                                          flex: 3, isBold: true),
                                      _buildTableCell(tag.poleNo, flex: 3),
                                      Expanded(
                                        flex: 2,
                                        child: _buildStatusPill(tag.status),
                                      ),
                                      _buildTableCell(tag.remarks ?? '—',
                                          flex: 2),
                                      _buildActionButton(tag),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        )
                      else
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Text(
                              'No tags in this batch',
                              style: TextStyle(color: AppColors.textDisabled),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Footer note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.infoBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.infoBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.info,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Tag ID is allocated by the server from the Available pool',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.info,
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

  // ============================================================
  // HELPER METHODS
  // ============================================================

  Widget _buildDUField(DUState duState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DU CODE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderStrong),
            borderRadius: BorderRadius.circular(8),
          ),
          child: duState.isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading DUs...'),
                    ],
                  ),
                )
              : duState.dus.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No DUs available',
                        style: TextStyle(color: AppColors.textDisabled),
                      ),
                    )
                  : duState.dus.length == 1
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            duState.dus.first.displayName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<DU>(
                            value: duState.selectedDU,
                            isExpanded: true,
                            hint: const Text('Select DU'),
                            items: duState.dus.map((du) {
                              return DropdownMenuItem<DU>(
                                value: du,
                                child: Text(du.displayName),
                              );
                            }).toList(),
                            onChanged: (du) {
                              if (du != null) {
                                setState(() {
                                  _selectedWorkOrder = null;
                                  _selectedWorkOrderId = null;
                                  _workOrderController.clear();
                                });
                                ref
                                    .read(workOrderProvider.notifier)
                                    .clearSelectedWorkOrder();
                                // Only update the provider here. The
                                // build() sync block below reacts to
                                // duState.selectedDU changing and loads
                                // work orders + the latest batch exactly
                                // once. Loading here too was firing every
                                // request twice.
                                ref.read(duProvider.notifier).selectDU(du);
                              }
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildWorkOrderField(WorkOrderState workOrderState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WORK ORDER REFERENCE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        RawAutocomplete<WorkOrder>(
          textEditingController: _workOrderController,
          focusNode: _workOrderFocus,
          displayStringForOption: (wo) => wo.displayName,
          optionsBuilder: (value) => _searchWorkOrderOptions(value.text),
          onSelected: (wo) {
            setState(() {
              _selectedWorkOrder = wo;
              _selectedWorkOrderId = wo.workOrderCode;
            });
            ref.read(workOrderProvider.notifier).selectWorkOrder(wo);
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderStrong),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onSubmitted: (_) => onSubmitted(),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search work order',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  suffixIcon: workOrderState.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.search, size: 20),
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final wo = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(wo.workOrderCode),
                        subtitle: Text(wo.workOrderName),
                        onTap: () => onSelected(wo),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuantityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUANTITY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderStrong),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            initialValue: '24',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Enter quantity',
            ),
            onChanged: (value) {
              setState(() {
                _quantity = int.tryParse(value) ?? 1;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBatchField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderStrong),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Load My Current Batch ──────────────────────────────────────

  /// The batch this printerman created and has not printed yet. Not simply the
  /// newest batch: with two printermen on a shift, the newest could be the
  /// other person's, which would hide this one's own work and let both print
  /// the same batch.
  Future<void> _loadMyCurrentBatch() async {
    // Called from a build-time guard, so a rebuild arriving before the response
    // would fire a second GET /batches/my-current — and with it a second
    // GET /batches/{id}/tags.
    if (_isLoadingMyBatch) return;
    _isLoadingMyBatch = true;

    try {
      final batch =
          await ref.read(batchProvider.notifier).loadMyCurrentBatch();
      if (batch != null && mounted) {
        setState(() {
          _currentBatch = batch;
        });
        // Load the tags for this batch
        await _loadCurrentBatch(batch.batchId);
      } else {
        // No batch found - clear current batch
        if (mounted) {
          setState(() {
            _currentBatch = null;
            _currentBatchTags = null;
          });
        }
      }
    } catch (e) {
      // No batch found - that's fine, show empty state
      if (mounted) {
        setState(() {
          _currentBatch = null;
          _currentBatchTags = null;
        });
      }
    } finally {
      _isLoadingMyBatch = false;
    }
  }

  // ─── Generate Batch ──────────────────────────────────────────────

  Future<void> _generateBatch() async {
    // ─── Validation ──────────────────────────────────────────────
    if (_selectedDU == null) {
      _showError('Please select a DU');
      return;
    }

    if (_selectedWorkOrder == null) {
      _showError('Please select a Work Order');
      return;
    }

    if (_quantity < 1 || _quantity > 1000) {
      _showError('Quantity must be between 1 and 1000');
      return;
    }

    // ─── Start Loading ───────────────────────────────────────────
    setState(() => _isGenerating = true);

    try {
      // ─── Call API to create batch ─────────────────────────────
      final batch = await ref.read(batchProvider.notifier).createBatch(
            duId: _selectedDU!.duId,
            workOrderId: _selectedWorkOrder!.workOrderId,
            quantity: _quantity,
          );

      // ─── Success ───────────────────────────────────────────────
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Batch ${batch.batchCode} created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );

        // ─── Load the batch tags ────────────────────────────────
        await _loadCurrentBatch(batch.batchId);

        // ─── Set current batch ───────────────────────────────────
        setState(() {
          _currentBatch = batch;
        });

        // The code just used is taken, so ask the server for the next one.
        await ref.read(duProvider.notifier).loadNextBatchCode();

        // Creating a batch claims tags out of the pool, so the tiles are stale.
        await ref.read(printermanStatsProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  // ─── Load Current Batch ─────────────────────────────────────────

  Future<void> _loadCurrentBatch(int batchId) async {
    setState(() => _isLoadingBatch = true);

    try {
      final tags =
          await ref.read(tagProvider.notifier).loadBatchTags(batchId);
      if (mounted) {
        setState(() {
          _currentBatchTags = tags;
          _isLoadingBatch = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBatch = false);
        _showError('Failed to load batch tags: $e');
      }
    }
  }

  // ─── Status Pill ─────────────────────────────────────────────────

  Widget _buildStatusPill(String status) {
    final color = AppColors.tagStatus(status);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
      ),
    );
  }

  // ─── Action Button ───────────────────────────────────────────────

  Widget _buildActionButton(Tag tag) {
    return SizedBox(
      width: 140,
      child: TextButton(
        onPressed: () {
          _showStatusPicker(tag);
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          backgroundColor: AppColors.infoBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          minimumSize: const Size(80, 32),
        ),
        child: Text(
          'Edit status',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.infoText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ─── Status Picker ──────────────────────────────────────────────

  /// The ID picker for the tag whose row was clicked.
  void _showStatusPicker(Tag tag) {
    final batch = _currentBatch;
    if (batch == null) return;

    showDialog(
      context: context,
      builder: (_) => _IdPickerDialog(
        batch: batch,
        tag: tag,
        onChanged: (updated) {
          if (!mounted) return;
          setState(() => _currentBatchTags = updated);
        },
      ),
    );
  }

  // ─── Print Modal ─────────────────────────────────────────────────

  /// One sheet for the whole print loop: it prints what still needs paper and
  /// it is where printed tags get flagged lost. Both live together because they
  /// are the same job — you look at the batch, see what came out wrong, and
  /// send those codes round again.
  void _showPrintModal(Batch batch, List<Tag> tags) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PrintSheet(
        batch: batch,
        initialTags: tags,
        // Takes the sheet's own result instead of re-fetching it, so the card
        // behind the sheet stays in step for free.
        onChanged: (tags, updatedBatch) {
          if (!mounted) return;
          setState(() {
            _currentBatchTags = tags;
            if (updatedBatch != null) _currentBatch = updatedBatch;
          });
          // Printing and flagging both move tags between statuses, which is
          // exactly what the three org-wide tiles count.
          ref.read(printermanStatsProvider.notifier).refresh();
        },
      ),
    );
  }

  // ─── Error Handler ──────────────────────────────────────────────

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  // ─── Stat Card ──────────────────────────────────────────────────

  // ─── Table Helpers ──────────────────────────────────────────────

  Widget _buildTableHeader(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTableCell(
    String text, {
    int flex = 1,
    bool isBold = false,
    bool isStatus = false,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          color: isStatus ? AppColors.success : null,
        ),
      ),
    );
  }
}

// ============================================================
// ID PICKER — CHANGE STATUS
// ============================================================

/// The statuses a printerman can set by hand, and what each one means.
///
/// Deliberately not the full [TagStatus] list. Printed, Dispatched and
/// Installed are set by the flows that actually do those things — printing,
/// handing a batch over, a crew putting a tag on a pole — so offering them here
/// would let someone claim an event that never happened. What is left are the
/// three a person genuinely decides:
const _manualStatuses = <String, String>{
  'Available':
      'Back in the pool. The code can be printed again.',
  'Do Not Use':
      'The code itself is unusable — it reads as something that cannot go up on '
          'a pole in public. Withdrawn for good; it will never be printed.',
  'Lost Printed':
      'The printed tag went missing before it reached a pole. The code goes '
          'back round for a reprint.',
  'Jam Paper':
      'The paper jammed and the tag never printed properly. The code goes back '
          'round for a reprint.',
};

/// Statuses that take a tag out of use and therefore have to say why. Mirrors
/// STATUSES_REQUIRING_REMARKS on the server, which is what actually enforces
/// it — this only spares the user a round trip to be told.
const _statusesRequiringRemarks = {'Do Not Use', 'Lost Printed', 'Jam Paper'};

class _IdPickerDialog extends ConsumerStatefulWidget {
  final Batch batch;

  final Tag tag;

  /// Passed the updated tag list after a successful change, so the table behind
  /// the dialog follows along without re-fetching what we already have.
  final void Function(List<Tag> tags) onChanged;

  const _IdPickerDialog({
    required this.batch,
    required this.tag,
    required this.onChanged,
  });

  @override
  ConsumerState<_IdPickerDialog> createState() => _IdPickerDialogState();
}

class _IdPickerDialogState extends ConsumerState<_IdPickerDialog> {
  final TextEditingController _remarksController = TextEditingController();

  late String _newStatus = _defaultStatusFor(widget.tag);
  bool _remarksMissing = false;
  bool _isSaving = false;

  /// Shows the tag's current status when it is one a person can set, so the
  /// dropdown opens reflecting reality. A tag mid-flow (Printed, Dispatched,
  /// Installed) has no manual equivalent, so those fall back to Available —
  /// the only sensible thing to do to a tag you are correcting by hand.
  String _defaultStatusFor(Tag tag) {
    if (_manualStatuses.containsKey(tag.status)) return tag.status;
    return 'Available';
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  bool get _remarksRequired => _statusesRequiringRemarks.contains(_newStatus);

  Future<void> _apply() async {
    final remarks = _remarksController.text.trim();

    if (_remarksRequired && remarks.isEmpty) {
      setState(() => _remarksMissing = true);
      return;
    }

    if (_newStatus == widget.tag.status && remarks.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _remarksMissing = false;
      _isSaving = true;
    });

    try {
      await ref.read(tagProvider.notifier).bulkUpdateStatus(
            [widget.tag.tagId],
            _newStatus,
            remarks: remarks.isEmpty ? null : remarks,
          );

      // Re-read once and hand the result to the caller, rather than letting both
      // this dialog and the screen behind it fetch the same rows.
      final fresh = await ref
          .read(tagProvider.notifier)
          .loadBatchTags(widget.batch.batchId);
      if (!mounted) return;
      widget.onChanged(fresh);

      final code = widget.tag.tagCode;
      final status = _newStatus;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('$code set to $status'),
          backgroundColor: AppColors.brand,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Failed to change status: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
      title: Row(
        children: [
          const Expanded(
            child: Text(
              'Edit status',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            color: AppColors.textSecondary,
            tooltip: 'Close',
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── The tag in hand ──────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      widget.tag.tagCode,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              'Pole ${widget.tag.poleNo}',
                              widget.batch.batchCode,
                              if (widget.batch.workOrder != null)
                                widget.batch.workOrder!.workOrderCode,
                            ].join(' · '),
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          _statusPill(widget.tag.status),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── New status ───────────────────────────────────
              _label('CHANGE STATUS TO'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _newStatus,
                isExpanded: true,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _manualStatuses.keys
                    .map((s) => DropdownMenuItem<String>(
                          value: s,
                          child: Text(s, style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: _isSaving
                    ? null
                    : (s) {
                        if (s == null) return;
                        setState(() {
                          _newStatus = s;
                          // The old warning does not apply to the new choice.
                          _remarksMissing = false;
                        });
                      },
              ),
              const SizedBox(height: 6),
              Text(
                _manualStatuses[_newStatus] ?? '',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // ─── Remarks ──────────────────────────────────────
              Row(
                children: [
                  _label('REMARKS'),
                  const Spacer(),
                  Text(
                    _remarksRequired ? 'required for $_newStatus' : 'optional',
                    style: TextStyle(
                      fontSize: 11,
                      color: _remarksRequired
                          ? AppColors.warningText
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _remarksController,
                enabled: !_isSaving,
                maxLines: 3,
                // Matches the endpoint's cap, so an over-long remark is stopped
                // here rather than coming back as a 422.
                maxLength: 1000,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: switch (_newStatus) {
                    'Do Not Use' => 'Why can this code not be used?',
                    'Lost Printed' => 'Where and how was it lost?',
                    'Jam Paper' => 'What happened in the printer?',
                    _ => 'Anything worth noting (optional)',
                  },
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorText: _remarksMissing
                      ? 'A reason is required to set $_newStatus.'
                      : null,
                ),
                onChanged: (_) {
                  if (_remarksMissing) {
                    setState(() => _remarksMissing = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actions: [
        OutlinedButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _apply,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: AppColors.onBrand,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.onBrand),
                )
              : const Text('Apply change'),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: 0.5,
        ),
      );
}

// ============================================================
// SHARED HELPERS
// ============================================================

/// Whether this tag still has to reach paper.
///
/// Three cases: it has never been printed (Available), the printed one was lost
/// (Lost Printed), or the paper jammed and it never printed properly (Jam
/// Paper). Everything else is left alone — already Printed, out with a crew,
/// Installed, Damaged, or withdrawn as Do Not Use — so a reprint sends only the
/// codes that actually need re-running rather than the whole batch again.
///
/// Do Not Use is excluded on purpose and permanently: that code reads as
/// something that cannot go up on a pole in public, so it must never reach paper
/// no matter how many times the batch is printed.
///
/// Mirrors PRINTABLE_TAG_STATUSES on the server, which is what the print flow
/// and batch creation actually enforce.
bool _needsPrint(Tag tag) {
  const printable = {'available', 'lost printed', 'jam paper'};
  return printable.contains(tag.status.toLowerCase());
}

/// The small coloured status chip used by both sheets.
Widget _statusPill(String status) {
  final color = AppColors.tagStatus(status);

  return Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    ),
  );
}

// ============================================================
// PRINT SHEET
// ============================================================

/// The whole print loop in one sheet: it sends whatever still needs paper, and
/// it is where a printed tag gets flagged lost so its code comes round again.
///
/// Both jobs live here because they are the same job. The printerman prints,
/// looks at what came out, and marks the jams — so the sheet stays open after a
/// print and simply re-reads the batch, rather than closing and popping a
/// second dialog. Every tag in the batch is listed with its real status, so it
/// is always clear which codes are done, which are queued, and which were lost.
class _PrintSheet extends ConsumerStatefulWidget {
  final Batch batch;
  final List<Tag> initialTags;

  /// Lets the card behind the sheet follow along without the sheet closing.
  ///
  /// Handed the rows the sheet has just read, rather than being a bare "go and
  /// refresh" signal — the sheet has already paid for that request, and having
  /// the parent fetch the same tags again made every print and lost-flag issue
  /// two identical GET /batches/{id}/tags calls. `updatedBatch` is non-null only
  /// when the batch row itself changed, so the status badge behind the sheet
  /// does not go stale either.
  final void Function(List<Tag> tags, Batch? updatedBatch) onChanged;

  const _PrintSheet({
    required this.batch,
    required this.initialTags,
    required this.onChanged,
  });

  @override
  ConsumerState<_PrintSheet> createState() => _PrintSheetState();
}

class _PrintSheetState extends ConsumerState<_PrintSheet> {
  /// Server order is authoritative — GET /batches/{id}/tags sorts by tag_id, so
  /// the list never reshuffles when a status changes.
  late List<Tag> _tags = widget.initialTags;

  /// Ids rather than Tag objects, so a tick survives the list being re-read.
  final Set<int> _lostTagIds = {};
  final TextEditingController _remarksController = TextEditingController();
  bool _isBusy = false;
  bool _remarksMissing = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  List<Tag> get _printable => _tags.where(_needsPrint).toList();

  bool get _hasTicks => _lostTagIds.isNotEmpty;

  /// Only a tag that actually reached paper can be lost. An Available one has
  /// not been printed yet, and a Lost one is already flagged.
  bool _canFlagLost(Tag tag) => tag.status.toLowerCase() == 'printed';

  void _toggleLost(int tagId) {
    setState(() {
      // remove() reports whether it was present, which makes this a toggle.
      if (!_lostTagIds.remove(tagId)) {
        _lostTagIds.add(tagId);
      }
      // The remark only applies while something is ticked.
      if (_lostTagIds.isEmpty) _remarksMissing = false;
    });
  }

  /// Re-reads the batch's tags once and shares that single result with the
  /// screen behind the sheet.
  Future<void> _reload({Batch? updatedBatch}) async {
    final tags = await ref
        .read(tagProvider.notifier)
        .loadBatchTags(widget.batch.batchId);
    if (!mounted) return;
    setState(() => _tags = tags);
    widget.onChanged(tags, updatedBatch);
  }

  // ─── Print ──────────────────────────────────────────────────────

  Future<void> _print() async {
    final printable = _printable;
    if (printable.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isBusy = true);

    try {
      // Nothing is marked until the printer takes the job: a cancelled dialog
      // must leave the codes untouched, or codes that never reached paper are
      // burned.
      final pdfBytes = await TagSheetPdf.build(
        batch: widget.batch,
        tags: printable,
      );

      final sentToPrinter = await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: '${widget.batch.batchCode}.pdf',
      );

      if (!sentToPrinter) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Print cancelled — nothing was marked as printed.'),
          ),
        );
        return;
      }

      // One bulk call per 100 tags, not one per tag.
      await ref.read(tagProvider.notifier).bulkUpdateStatus(
            printable.map((t) => t.tagId).toList(),
            'Printed',
          );
      // Returns the saved row, so the fresh batch comes back from the call that
      // changed it rather than needing a GET of its own.
      final updatedBatch =
          await ref.read(batchProvider.notifier).updateBatchStatus(
                widget.batch.batchId,
                'Printed',
              );

      await _reload(updatedBatch: updatedBatch);

      messenger.showSnackBar(
        SnackBar(
          content: Text('✅ ${printable.length} tags printed'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Failed to print: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ─── Flag lost ──────────────────────────────────────────────────

  Future<void> _flagLost() async {
    final remarks = _remarksController.text.trim();

    // Required, not optional: a tag written off as Lost with no reason recorded
    // is a code nobody can account for when the batch is audited later.
    if (remarks.isEmpty) {
      setState(() => _remarksMissing = true);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final flaggedCount = _lostTagIds.length;

    setState(() {
      _remarksMissing = false;
      _isBusy = true;
    });

    try {
      await ref.read(tagProvider.notifier).bulkUpdateStatus(
            _lostTagIds.toList(),
            'Lost Printed',
            remarks: remarks,
          );

      _lostTagIds.clear();
      _remarksController.clear();
      await _reload();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$flaggedCount tag ID(s) flagged Lost — ready to reprint',
          ),
          backgroundColor: AppColors.warningText,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Failed to flag tags: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final printableCount = _printable.length;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ──────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.print, color: AppColors.infoText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Review tags to print',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.batch.batchCode} · $printableCount of '
                      '${_tags.length} tag IDs queued',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isBusy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                color: AppColors.textSecondary,
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ─── Tag Table ──────────────────────────────────────────
          Container(
            constraints: const BoxConstraints(maxHeight: 380),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderStrong),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    border: Border(
                      bottom: BorderSide(color: AppColors.borderStrong),
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      _header('CODE', flex: 3),
                      _header('POLE NO.', flex: 3),
                      _header('STATUS', flex: 3),
                      _header('LOST?', flex: 3, alignRight: true),
                    ],
                  ),
                ),
                // Table Rows
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(children: _tags.map(_buildRow).toList()),
                  ),
                ),
              ],
            ),
          ),

          // ─── Remarks (only once something is ticked) ─────────────
          if (_hasTicks) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warningBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REMARKS FOR LOST TAGS (REQUIRED)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _remarksController,
                    enabled: !_isBusy,
                    maxLines: 2,
                    // Matches the endpoint's cap, so an over-long remark is
                    // stopped here rather than coming back as a 422.
                    maxLength: 1000,
                    decoration: InputDecoration(
                      hintText: 'Where and how were they lost?',
                      filled: true,
                      fillColor: AppColors.surface,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      errorText: _remarksMissing
                          ? 'Remarks are required to flag tags as lost.'
                          : null,
                    ),
                    onChanged: (_) {
                      if (_remarksMissing) {
                        setState(() => _remarksMissing = false);
                      }
                    },
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warningBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only tag IDs awaiting print or flagged lost are sent to '
                      'paper. Tick a printed tag to send its code round again.',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ─── Buttons ─────────────────────────────────────────────
          // One primary action, whose job follows the sheet's state: with tags
          // ticked it saves them as Lost, otherwise it prints what is queued.
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isBusy ? null : () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isBusy || (!_hasTicks && printableCount == 0)
                      ? null
                      : (_hasTicks ? _flagLost : _print),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: AppColors.onBrand,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isBusy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onBrand,
                          ),
                        )
                      : Text(
                          _hasTicks
                              ? 'Flag lost & reprint'
                              : printableCount == 0
                                  ? 'Nothing to print'
                                  : 'Print tags',
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Row / Header Helpers ───────────────────────────────────────

  Widget _header(String text, {int flex = 1, bool alignRight = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildRow(Tag tag) {
    final isTicked = _lostTagIds.contains(tag.tagId);
    final canFlag = _canFlagLost(tag);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isTicked ? AppColors.dangerBg : null,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              tag.tagCode,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              tag.poleNo,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          // Shows Lost the moment it is ticked, so the row reflects what saving
          // will do rather than what the server currently holds.
          Expanded(
            flex: 3,
            child: _statusPill(isTicked ? 'Lost Printed' : tag.status),
          ),
          Expanded(
            flex: 3,
            child: canFlag
                ? InkWell(
                    onTap: _isBusy ? null : () => _toggleLost(tag.tagId),
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: isTicked,
                            visualDensity: VisualDensity.compact,
                            onChanged: _isBusy
                                ? null
                                : (_) => _toggleLost(tag.tagId),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mark lost',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  )
                // Nothing to lose yet (Available) or already flagged (Lost).
                : Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '—',
                      style: TextStyle(fontSize: 13, color: AppColors.textFaint),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
