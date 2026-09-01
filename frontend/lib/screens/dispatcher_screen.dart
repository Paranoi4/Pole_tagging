// 📁 lib/screens/dispatcher_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/widgets/stat_card.dart';
import 'package:frontend/config/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/providers/auth_providers.dart';
import 'package:frontend/models/batch.dart';
import 'package:frontend/models/crew.dart';
import 'package:frontend/models/tag.dart';
import 'package:frontend/providers/batch_provider.dart';
import 'package:frontend/providers/api_providers.dart';

class DispatcherScreen extends ConsumerStatefulWidget {
  const DispatcherScreen({super.key});

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

  // ─── Dispatch flow ──────────────────────────────────────────────
  // Step 1 counts the sheet against the tag list; step 2 picks the crew. Kept
  // as a step rather than showing both at once so the count is confirmed
  // before anyone can hand the batch over.
  int _step = 1;

  /// Crews per DU, cached. Fetched only when a DU's crews are actually needed —
  /// opening step 2, or selecting a dispatched batch whose crew has to be
  /// named — and kept, so moving between batches in the same DU refetches
  /// nothing.
  final Map<int, List<Crew>> _crewsByDu = {};
  int? _loadingCrewsForDu;
  Crew? _selectedCrew;
  bool _isDispatching = false;

  /// True while a dispatched batch's crew is being corrected — the read-only
  /// panel swaps to a crew picker without the batch leaving Dispatched.
  bool _isChangingCrew = false;

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

  // ─── Dispatch flow ──────────────────────────────────────────────

  /// Picking a different batch drops back to step 1. The count has to be
  /// confirmed against the batch actually on the table, and a crew chosen for
  /// the previous batch may not even cover this one's DU.
  void _selectBatch(int index) {
    setState(() {
      selectedBatchIndex = index;
      _step = 1;
      _selectedCrew = null;
      _isChangingCrew = false;
    });
  }

  Future<void> _loadCrewsForDu(int duId) async {
    if (_crewsByDu.containsKey(duId) || _loadingCrewsForDu == duId) return;
    setState(() => _loadingCrewsForDu = duId);
    try {
      // Scoped to the DU server-side, so the dropdown can only ever offer crews
      // who work this batch's poles.
      final crews = await ref.read(apiProvider).getAllCrews(duId: duId);
      if (!mounted) return;
      setState(() {
        _crewsByDu[duId] = crews;
        _loadingCrewsForDu = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCrewsForDu = null);
      _showError('Failed to load crews: $e');
    }
  }

  /// The crew a dispatched batch went to, or null while the DU's crews are
  /// still loading (or if the crew has since been deleted — the FK is
  /// ON DELETE SET NULL, so that is a real possibility).
  Crew? _crewFor(Batch batch) {
    final crewId = batch.assignedCrewId;
    if (crewId == null) return null;
    for (final crew in _crewsByDu[batch.duId] ?? const <Crew>[]) {
      if (crew.crewId == crewId) return crew;
    }
    return null;
  }

  /// Asks before handing over, because dispatching is the point of no return in
  /// this screen: the tags become someone else's responsibility in the field
  /// and the batch leaves the dispatch list.
  Future<void> _confirmDispatch(Batch batch, Crew crew) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text('Hand this batch to ${crew.crewLabel}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'These tag IDs move to Dispatched and become '
              "${crew.crewLabel}'s responsibility in the field.",
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _summaryItem('Batch', batch.batchCode),
                  _summaryItem('Quantity', '${_selectedBatchTags.length}'),
                  _summaryItem('Crew', crew.crewLabel),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A7A3D),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Yes, dispatch'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _dispatch(batch, crew);
  }

  Future<void> _dispatch(Batch batch, Crew crew) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isDispatching = true);

    try {
      await ref.read(apiProvider).dispatchBatchToCrew(
            batch.batchId,
            crew.crewId,
          );

      // The batch is Dispatched now, so it drops out of the list this screen
      // shows. Reset to step 1 and let the reload pick the next one.
      if (!mounted) return;
      setState(() {
        _step = 1;
        _selectedCrew = null;
        selectedBatchIndex = 0;
        _tagsLoadedForBatchId = null;
        _selectedBatchTags = [];
        _isDispatching = false;
      });
      await ref.read(batchProvider.notifier).loadAllBatches();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '✅ ${batch.batchCode} dispatched to ${crew.crewLabel}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDispatching = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Failed to dispatch: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Corrects who holds an already-dispatched batch. Confirms first, because the
  /// tags physically change hands — this is not just an edit to a record.
  Future<void> _confirmChangeCrew(Batch batch, Crew crew) async {
    final current = _crewFor(batch);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Hand this batch to ${crew.crewLabel} instead?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              current == null
                  ? 'These tag IDs become ${crew.crewLabel}\'s responsibility '
                      'in the field.'
                  : 'These tag IDs move from ${current.crewLabel} to '
                      '${crew.crewLabel}. The time the batch went out does not '
                      'change — only who is holding it.',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _summaryItem('Batch', batch.batchCode),
                  _summaryItem('Quantity', '${_selectedBatchTags.length}'),
                  if (current != null) _summaryItem('From', current.crewLabel),
                  _summaryItem('To', crew.crewLabel),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A7A3D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes, hand over'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isDispatching = true);
    try {
      // Same endpoint as the first hand-over. The server sees the batch is
      // already Dispatched and changes only the crew.
      await ref
          .read(apiProvider)
          .dispatchBatchToCrew(batch.batchId, crew.crewId);
      if (!mounted) return;
      setState(() {
        _isChangingCrew = false;
        _selectedCrew = null;
        _isDispatching = false;
      });
      await ref.read(batchProvider.notifier).loadAllBatches();
      messenger.showSnackBar(
        SnackBar(
          content: Text('✅ ${batch.batchCode} now with ${crew.crewLabel}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDispatching = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Failed to change crew: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Pulls a dispatched batch back. Everything about the hand-over is undone
  /// server-side — batch and tags to Printed, crew and dispatch time cleared —
  /// so the batch returns to the top of the dispatch list.
  Future<void> _confirmReturnBatch(Batch batch) async {
    final crew = _crewFor(batch);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Return this batch?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              crew == null
                  ? 'These tag IDs go back to Printed and the batch returns to '
                      'the dispatch list.'
                  : 'These tag IDs come back from ${crew.crewLabel}, return to '
                      'Printed, and the batch goes back on the dispatch list. '
                      'The recorded dispatch time is cleared.',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _summaryItem('Batch', batch.batchCode),
                  _summaryItem('Quantity', '${_selectedBatchTags.length}'),
                  if (crew != null) _summaryItem('From', crew.crewLabel),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes, return batch'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isDispatching = true);
    try {
      await ref.read(apiProvider).returnBatch(batch.batchId);
      if (!mounted) return;
      setState(() {
        _isChangingCrew = false;
        _selectedCrew = null;
        _step = 1;
        _tagsLoadedForBatchId = null;
        _selectedBatchTags = [];
        _isDispatching = false;
      });
      await ref.read(batchProvider.notifier).loadAllBatches();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${batch.batchCode} returned — ready to dispatch again'),
          backgroundColor: Colors.orange[800],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDispatching = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Failed to return batch: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// A batch that has already gone out. Read-only on purpose: the tags are in
  /// the field and the hand-over cannot be repeated, so this states who has
  /// them rather than offering buttons that would only be refused.
  Widget _buildDispatchedFooter(Batch batch) {
    final crew = _crewFor(batch);
    final stillLoading = _loadingCrewsForDu == batch.duId;
    final crewName = stillLoading
        ? 'Loading crew…'
        : crew == null
            // assigned_crew_id is ON DELETE SET NULL, so a deleted crew leaves
            // the batch dispatched with nobody named against it.
            ? 'Crew no longer on record'
            : crew.city != null
                ? '${crew.crewLabel} · ${crew.city!.cityName}'
                : crew.crewLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Who has it ─────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.local_shipping, size: 18, color: Colors.orange[800]),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DISPATCHED TO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      crewName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_selectedBatchTags.length} tag IDs in the field',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ─── Corrections ────────────────────────────────────────
        Row(
          children: [
            ElevatedButton(
              onPressed: _isDispatching
                  ? null
                  : () => setState(() {
                        _isChangingCrew = !_isChangingCrew;
                        _selectedCrew = null;
                        if (_isChangingCrew) _loadCrewsForDu(batch.duId);
                      }),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A7A3D),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(_isChangingCrew ? 'Cancel change' : 'Change crew'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed:
                  _isDispatching ? null : () => _confirmReturnBatch(batch),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange[800],
                side: BorderSide(color: Colors.orange[300]!),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Return batch'),
            ),
            if (_isDispatching) ...[
              const SizedBox(width: 16),
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),

        // ─── Crew picker, only while correcting ─────────────────
        if (_isChangingCrew) ...[
          const SizedBox(height: 12),
          _buildChangeCrewPanel(batch, crew),
        ],
      ],
    );
  }

  /// The crew picker shown while correcting a dispatched batch. Same DU-scoped
  /// list as the original hand-over, so it cannot offer a crew the server would
  /// refuse.
  Widget _buildChangeCrewPanel(Batch batch, Crew? currentCrew) {
    final crews = _crewsByDu[batch.duId] ?? const <Crew>[];
    final isLoadingCrews = _loadingCrewsForDu == batch.duId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentCrew == null
                ? 'Pick the crew that should have these stickers.'
                : 'These stickers are with ${currentCrew.crewLabel}. Pick the '
                    'crew that should have them instead.',
            style: TextStyle(fontSize: 12, color: Colors.orange[900]),
          ),
          const SizedBox(height: 10),
          Text(
            'HAND OVER TO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: isLoadingCrews
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Loading crews…',
                                style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      )
                    : crews.isEmpty
                        ? const Text(
                            'No crews are set up for this DU.',
                            style:
                                TextStyle(fontSize: 12, color: Colors.orange),
                          )
                        : DropdownButtonFormField<Crew>(
                            value: _selectedCrew,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: 'Select field crew / stickerman...',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: crews
                                .map(
                                  (c) => DropdownMenuItem<Crew>(
                                    value: c,
                                    child: Text(
                                      c.city != null
                                          ? '${c.crewLabel} · ${c.city!.cityName}'
                                          : c.crewLabel,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _isDispatching
                                ? null
                                : (c) => setState(() => _selectedCrew = c),
                          ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _selectedCrew == null || _isDispatching
                    ? null
                    : () => _confirmChangeCrew(batch, _selectedCrew!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A7A3D),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Hand over'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Step 2: pick the crew, then hand over. The dropdown is fed from the DU
  /// scoped crew list, so there is nothing here to pick that would be rejected
  /// by the server.
  Widget _buildDispatchFooter(Batch? batch) {
    final crews =
        batch == null ? const <Crew>[] : (_crewsByDu[batch.duId] ?? const []);
    final isLoadingCrews = batch != null && _loadingCrewsForDu == batch.duId;
    final canDispatch =
        batch != null && _selectedCrew != null && !_isDispatching;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DISPATCHED TO',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: isLoadingCrews
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          SizedBox(
                            height: 18,
                            width: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Loading crews…',
                              style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    )
                  : crews.isEmpty
                      // A DU with no crew placed in any of its cities cannot
                      // receive a batch — say so rather than showing an empty
                      // dropdown that looks broken.
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: const Text(
                            'No crews are set up for this DU yet. Add a crew to '
                            'a city under this DU before dispatching.',
                            style:
                                TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                        )
                      : DropdownButtonFormField<Crew>(
                          value: _selectedCrew,
                          isExpanded: true,
                          decoration: InputDecoration(
                            hintText: 'Select field crew / stickerman...',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: crews
                              .map(
                                (crew) => DropdownMenuItem<Crew>(
                                  value: crew,
                                  child: Text(
                                    crew.city != null
                                        ? '${crew.crewLabel} · ${crew.city!.cityName}'
                                        : crew.crewLabel,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _isDispatching
                              ? null
                              : (crew) =>
                                  setState(() => _selectedCrew = crew),
                        ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: canDispatch
                  ? () => _confirmDispatch(batch, _selectedCrew!)
                  : null,
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
              child: _isDispatching
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirm dispatch'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed:
              _isDispatching ? null : () => setState(() => _step = 1),
          child: const Text('← Back to quantity'),
        ),
      ],
    );
  }

  Widget _summaryItem(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final batchState = ref.watch(batchProvider);
    // Printed batches are the ones still to hand over; Dispatched ones are kept
    // in the list so the dispatcher can look back at what went out and to whom.
    // Printed first, because those are the actionable ones.
    final dispatchableBatches =
        batchState.batches.where((b) => b.status == 'Printed').toList();
    final dispatchedBatches =
        batchState.batches.where((b) => b.status == 'Dispatched').toList();
    final visibleBatches = [...dispatchableBatches, ...dispatchedBatches];

    final hasBatches = visibleBatches.isNotEmpty;
    final readyToDispatch =
        dispatchableBatches.fold<int>(0, (sum, b) => sum + b.quantity);
    final dispatchedTagCount =
        dispatchedBatches.fold<int>(0, (sum, b) => sum + b.quantity);
    if (selectedBatchIndex >= visibleBatches.length) selectedBatchIndex = 0;
    final Batch? selectedBatch =
        hasBatches ? visibleBatches[selectedBatchIndex] : null;

    // A dispatched batch is history: its tags are already with a crew, so the
    // panel shows them read-only instead of offering the hand-over flow again.
    final bool isSelectedDispatched = selectedBatch?.status == 'Dispatched';

    // Watched, not passed in from the route. On a browser refresh the route is
    // built before the session is restored, so a flag computed there is false
    // and stays false; watching means the icon appears as soon as the roles
    // land.
    final showPrintermanShortcut = ref
            .watch(authProvider)
            .user
            ?.roles
            .any((role) => role.roleName == 'Printerman') ??
        false;

    // Whenever the selected batch changes, fetch its real tags.
    // _loadTagsForBatch bails out early if we already have this batch's
    // tags, so this is safe to call on every build.
    if (selectedBatch != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadTagsForBatch(selectedBatch.batchId);
        // A dispatched batch needs its DU's crews straight away, to name who is
        // holding the tags. Cached per DU, so this is a no-op once loaded.
        if (isSelectedDispatched) _loadCrewsForDu(selectedBatch.duId);
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
          if (showPrintermanShortcut)
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
                        child: StatCard(
                          label: 'READY TO DISPATCH',
                          value: '$readyToDispatch',
                          subtitle: 'printed tags on hand',
                          valueColor: AppColors.brand,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: StatCard(
                          label: 'OPEN BATCHES',
                          value: '${dispatchableBatches.length}',
                          subtitle: 'awaiting assignment',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: StatCard(
                          label: 'DISPATCHED',
                          value: '$dispatchedTagCount',
                          subtitle: 'tags with field crew',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSelectedBatchCard(
                          selectedBatch?.batchCode ?? '—',
                          hasBatches
                              ? '${selectedBatch!.quantity} tags · '
                                  '${selectedBatch.status.toLowerCase()}'
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
                                      ...visibleBatches
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        final i = entry.key;
                                        final batch = entry.value;
                                        final isSelected =
                                            i == selectedBatchIndex;
                                        return InkWell(
                                          onTap: _isDispatching
                                              ? null
                                              : () => _selectBatch(i),
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
                                                    // The list now holds both
                                                    // Printed and Dispatched
                                                    // batches, so the pill has
                                                    // to say which.
                                                    child: _statusPill(
                                                        batch.status),
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
                                              ? 'DU #${selectedBatch!.duId} · '
                                                  '${selectedBatch.status.toLowerCase()}'
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
                                  // An already dispatched batch has been
                                  // through both steps, so neither reads as
                                  // pending.
                                  _buildStep('1', 'Confirm quantity',
                                      isActive:
                                          isSelectedDispatched || _step == 1),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      color: isSelectedDispatched || _step == 2
                                          ? const Color(0xFF1A7A3D)
                                          : Colors.grey[300],
                                    ),
                                  ),
                                  _buildStep('2', 'Dispatch to crew',
                                      isActive:
                                          isSelectedDispatched || _step == 2),
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
                                                                      _statusPill(
                                                                          tag.status),
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

                              // Footer: step 1 confirms the count, step 2 picks
                              // the crew and hands the batch over.
                              if (isSelectedDispatched)
                                _buildDispatchedFooter(selectedBatch!)
                              else if (_step == 1)
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
                                      // Nothing to confirm until the tags are
                                      // actually on screen to count against.
                                      onPressed: selectedBatch == null ||
                                              _isLoadingTags ||
                                              _selectedBatchTags.isEmpty
                                          ? null
                                          : () {
                                              setState(() => _step = 2);
                                              _loadCrewsForDu(
                                                  selectedBatch.duId);
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF1A7A3D),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text('Confirm quantity'),
                                    ),
                                  ],
                                )
                              else
                                _buildDispatchFooter(selectedBatch),
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

  /// Status chip coloured from the status itself. Both the batch list and the
  /// tag list now show more than one status, so the colours cannot be fixed at
  /// the call site any more.
  Widget _statusPill(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'available':
        color = const Color(0xFF1A7A3D);
        break;
      case 'printed':
        color = Colors.blue;
        break;
      case 'dispatched':
        color = Colors.orange[800]!;
        break;
      case 'installed':
        color = Colors.purple;
        break;
      case 'lost printed':
      case 'damaged':
        color = Colors.red;
        break;
      case 'jam paper':
        color = Colors.deepOrange;
        break;
      case 'do not use':
        color = Colors.blueGrey;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
