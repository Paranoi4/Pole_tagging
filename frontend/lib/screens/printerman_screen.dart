// 📁 lib/screens/printerman_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/providers/auth_providers.dart';
import 'package:frontend/providers/du_provider.dart';
import 'package:frontend/models/du.dart';
import 'package:frontend/providers/work_order_provider.dart';
import 'package:frontend/models/work_order.dart';
import 'package:frontend/providers/batch_provider.dart';
import 'package:frontend/models/batch.dart';
import 'package:frontend/models/tag.dart';
import 'package:frontend/providers/api_providers.dart';
import 'package:frontend/services/tag_sheet_pdf.dart';
import 'package:printing/printing.dart';

class PrinterManScreen extends ConsumerStatefulWidget {
  final bool showDispatcherShortcut;

  const PrinterManScreen({super.key, this.showDispatcherShortcut = false});

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

  // Tracks what the next-batch-code was last computed from, so we only
  // recompute only when the selected DU actually changes.
  DU? _nextCodeDU;

  // Work order type-ahead. The field is searched server-side rather than
  // filled with a full list: work orders accumulate indefinitely, and the
  // backend caps a search at 20.
  final TextEditingController _workOrderController = TextEditingController();
  final FocusNode _workOrderFocus = FocusNode();
  String _workOrderQuery = '';

  @override
  void dispose() {
    _workOrderController.dispose();
    _workOrderFocus.dispose();
    super.dispose();
  }

  /// Debounced search, so typing does not fire one request per character.
  /// A query that has been superseded returns nothing — the newer call is
  /// already in flight with the real results.
  Future<Iterable<WorkOrder>> _searchWorkOrderOptions(String query) async {
    _workOrderQuery = query;
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted || _workOrderQuery != query) return const <WorkOrder>[];

    try {
      return await ref.read(apiProvider).searchWorkOrders(search: query);
    } catch (_) {
      return const <WorkOrder>[];
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Just load the DU list here. build()'s sync block below already
      // reacts to duState.selectedDU changing and fires the batch/work
      // order loads exactly once — doing it here too caused every load
      // to fire twice (batches, tags, and work-orders all doubled).
      ref.read(duProvider.notifier).loadDUs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final duState = ref.watch(duProvider);
    final workOrderState = ref.watch(workOrderProvider);

    // Sync selected DU with provider state
    if (duState.selectedDU != null && _selectedDU != duState.selectedDU) {
      _selectedDU = duState.selectedDU;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadMyCurrentBatch();
        ref.read(workOrderProvider.notifier).searchWorkOrders();
      });
    }

    // Ask the server for the next batch code whenever the selected DU changes.
    // It is the same generator create_batch uses, so the form shows the code
    // the batch will actually get.
    if (_selectedDU != null && _nextCodeDU != _selectedDU) {
      _nextCodeDU = _selectedDU;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(duProvider.notifier).loadNextBatchCode();
      });
    }

    // Sync selected Work Order with provider state, and show it in the
    // type-ahead field. Skipped while the field has focus, so it never
    // overwrites what someone is in the middle of typing.
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

    // Check if batch is in Pending status (ready to print)
    final bool canPrint = _currentBatch != null &&
        _currentBatch!.status.toLowerCase() == 'pending' &&
        _currentBatchTags != null &&
        _currentBatchTags!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Pole Tagging',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: false,
        actions: [
          if (widget.showDispatcherShortcut)
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
                        child: _buildStatCard(
                      'TOTAL PRINTED',
                      '29',
                      'tag IDs printed all-time',
                      Icons.print,
                      Colors.blue,
                    )),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildStatCard(
                      'AVAILABLE IN POOL',
                      '3,145,674',
                      'unassigned tag IDs',
                      Icons.inventory_2,
                      Colors.green,
                    )),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildStatCard(
                      'LOST PRINTED',
                      '1',
                      'awaiting reprint',
                      Icons.warning_amber_rounded,
                      Colors.orange,
                    )),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildStatCard(
                      'THIS BATCH QUANTITY',
                      '$_quantity',
                      _currentBatch != null
                          ? '${_currentBatch!.batchCode} - ${_currentBatch!.quantity} tags'
                          : 'BT-2026-0043 - awaiting print',
                      Icons.production_quantity_limits,
                      Colors.purple,
                    )),
                  ],
                ),

                const SizedBox(height: 32),

                // ============================================================
                // NEW PRINT BATCH
                // ============================================================
                Container(
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
                      const Text(
                        'New print batch',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
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
                              backgroundColor: const Color(0xFF1A7A3D),
                              foregroundColor: Colors.white,
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
                                      color: Colors.white,
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
                                    ? Colors.orange[50]
                                    : Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _currentBatch!.status.toLowerCase() ==
                                          'pending'
                                      ? Colors.orange[200]!
                                      : Colors.green[200]!,
                                ),
                              ),
                              child: Text(
                                '${_currentBatch!.batchCode} - ${_currentBatch!.quantity} tags - ${_currentBatch!.status}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _currentBatch!.status.toLowerCase() ==
                                          'pending'
                                      ? Colors.orange[800]
                                      : Colors.green[800],
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
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Text(
                                'No batch generated yet',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
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
                                backgroundColor: const Color(0xFF1A7A3D),
                                foregroundColor: Colors.white,
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
                            border: Border.all(color: Colors.grey[300]!),
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
                                  color: Colors.grey[100],
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey[300]!,
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
                                          color: Colors.black54,
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
                                        color: Colors.grey[200]!,
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
                              style: TextStyle(color: Colors.grey),
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
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Colors.blue,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Tag ID is allocated by the server from the Available pool',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue,
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
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
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
                        style: TextStyle(color: Colors.grey),
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
                                });
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
            color: Colors.grey[600],
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
                border: Border.all(color: Colors.grey[300]!),
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
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
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
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
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
    try {
      final batch = await ref.read(apiProvider).getMyCurrentBatch();
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
            backgroundColor: Colors.green,
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
      final tags = await ref.read(apiProvider).getBatchTags(batchId);
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
    Color color;
    switch (status.toLowerCase()) {
      case 'available':
        color = Colors.green;
        break;
      case 'printed':
        color = Colors.blue;
        break;
      case 'dispatched':
        color = Colors.orange;
        break;
      case 'installed':
        color = Colors.purple;
        break;
      case 'lost':
        color = Colors.red;
        break;
      case 'damaged':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

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
          backgroundColor: Colors.blue[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          minimumSize: const Size(80, 32),
        ),
        child: Text(
          'Edit status',
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ─── Status Picker ──────────────────────────────────────────────

  void _showStatusPicker(Tag tag) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _StatusPickerSheet(tag: tag),
    );
  }

  // ─── Print Modal ─────────────────────────────────────────────────

  void _showPrintModal(Batch batch, List<Tag> tags) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PrintConfirmSheet(
        batch: batch,
        tags: tags,
        onConfirm: () {
          // Refresh the batch after printing
          _loadCurrentBatch(batch.batchId);
        },
      ),
    );
  }

  // ─── Error Handler ──────────────────────────────────────────────

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ─── Stat Card ──────────────────────────────────────────────────

  Widget _buildStatCard(
    String label,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const Spacer(),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
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

  // ─── Table Helpers ──────────────────────────────────────────────

  Widget _buildTableHeader(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
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
          color: isStatus ? Colors.green : null,
        ),
      ),
    );
  }
}

// ============================================================
// STATUS PICKER SHEET
// ============================================================

class _StatusPickerSheet extends ConsumerStatefulWidget {
  final Tag tag;
  const _StatusPickerSheet({required this.tag});

  @override
  ConsumerState<_StatusPickerSheet> createState() => _StatusPickerSheetState();
}

class _StatusPickerSheetState extends ConsumerState<_StatusPickerSheet> {
  String _selectedStatus = '';
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.tag.status;
  }

  @override
  Widget build(BuildContext context) {
    final statuses = [
      'Available',
      'Printed',
      'Dispatched',
      'Installed',
      'Lost',
      'Damaged'
    ];

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
          const Text(
            'Update Status',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tag: ${widget.tag.tagCode}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ...statuses.map((status) {
            return RadioListTile<String>(
              title: Text(status),
              value: status,
              groupValue: _selectedStatus,
              onChanged: _isUpdating
                  ? null
                  : (value) {
                      setState(() => _selectedStatus = value!);
                    },
            );
          }),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isUpdating ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isUpdating
                      ? null
                      : () async {
                          setState(() => _isUpdating = true);

                          try {
                            // TODO: Call API to update tag status
                            // await ref.read(apiProvider).updateTagStatus(
                            //   widget.tag.tagId,
                            //   _selectedStatus,
                            // );

                            // Simulate API call
                            await Future.delayed(const Duration(seconds: 1));

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('✅ Status updated successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('❌ Failed to update status: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isUpdating = false);
                            }
                          }
                        },
                  child: _isUpdating
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update Status'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PRINT CONFIRM SHEET
// ============================================================

class _PrintConfirmSheet extends ConsumerStatefulWidget {
  final Batch batch;
  final List<Tag> tags;
  final VoidCallback onConfirm;

  const _PrintConfirmSheet({
    required this.batch,
    required this.tags,
    required this.onConfirm,
  });

  @override
  ConsumerState<_PrintConfirmSheet> createState() => _PrintConfirmSheetState();
}

class _PrintConfirmSheetState extends ConsumerState<_PrintConfirmSheet> {
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    final batch = widget.batch;
    final tags = widget.tags;

    // A tag held back as "Do Not Use" is one the office has taken out of
    // circulation. It still shows in the review list so the printerman can see
    // why the sheet is short, but it never reaches paper and never gets marked.
    final printableTags =
        tags.where((t) => t.status.toLowerCase() != 'do not use').toList();

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
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.print, color: Colors.blue[700]),
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
                      '${batch.batchCode} · ${printableTags.length} tag IDs queued',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ─── Tag Table ──────────────────────────────────────────
          Container(
            constraints: const BoxConstraints(maxHeight: 400),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
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
                    color: Colors.grey[100],
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'CODE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'POLE NO.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'STATUS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Table Rows
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[200]!),
                            ),
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
                              Expanded(
                                flex: 3,
                                child: _buildStatusPillSmall(tag.status),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ─── Footer Note ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.orange,
                ),
                SizedBox(width: 8),
                Text(
                  'Tag IDs set to Do Not Use are skipped',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── Buttons ─────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isPrinting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isPrinting || printableTags.isEmpty
                      ? null
                      : () async {
                          setState(() => _isPrinting = true);

                          try {
                            // 1. Build the sheet and hand it to a printer.
                            // Nothing is marked until this comes back true: a
                            // cancelled dialog or a printer that refused the
                            // job must leave the tag IDs untouched, or codes
                            // that never reached paper are burned.
                            final pdfBytes = await TagSheetPdf.build(
                              batch: batch,
                              tags: printableTags,
                            );

                            final sentToPrinter = await Printing.layoutPdf(
                              onLayout: (_) async => pdfBytes,
                              name: '${batch.batchCode}.pdf',
                            );

                            if (!sentToPrinter) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Print cancelled — nothing was marked as printed.',
                                    ),
                                  ),
                                );
                              }
                              return;
                            }

                            // 2. Update the printed tags to "Printed".
                            // One bulk call per 100 tags, not one call per tag:
                            // a 500-tag batch was 500 round trips.
                            await ref.read(apiProvider).bulkUpdateTagStatus(
                                  printableTags.map((t) => t.tagId).toList(),
                                  'Printed',
                                );

                            // 3. Update batch status to "Printed"
                            await ref.read(apiProvider).updateBatchStatus(
                                  batch.batchId,
                                  'Printed',
                                );

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '✅ ${printableTags.length} tags printed',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              // Refresh the batch
                              widget.onConfirm();
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('❌ Failed to print: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isPrinting = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A7A3D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isPrinting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Print tags'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Small Status Pill ──────────────────────────────────────────

  Widget _buildStatusPillSmall(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'available':
        color = Colors.green;
        break;
      case 'printed':
        color = Colors.blue;
        break;
      case 'dispatched':
        color = Colors.orange;
        break;
      case 'installed':
        color = Colors.purple;
        break;
      case 'lost':
        color = Colors.red;
        break;
      case 'damaged':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

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
}
