// 📁 lib/screens/dispatcher_screen.dart

import 'package:flutter/material.dart';

class DispatcherScreen extends StatefulWidget {
  const DispatcherScreen({super.key});

  @override
  State<DispatcherScreen> createState() => _DispatcherScreenState();
}

class _DispatcherScreenState extends State<DispatcherScreen> {
  // Hardcoded data
  final List<Map<String, String>> printedBatches = const [
    {
      'batchId': 'BT-2026-0041',
      'woRef': 'WO-2026-0118 · assigned to R. Villanueva',
      'qty': '17',
      'status': 'Ongoing',
    },
    {
      'batchId': 'BT-2026-0042',
      'woRef': 'WO-2026-0121 · unassigned',
      'qty': '11',
      'status': 'Available',
    },
  ];

  final List<Map<String, String>> selectedBatchTags = const [
    {'tagId': 'N31MJ', 'poleNo': '100018', 'status': 'Printed'},
    {'tagId': 'B31MK', 'poleNo': '100019', 'status': 'Printed'},
    {'tagId': 'N31ML', 'poleNo': '100020', 'status': 'Printed'},
    {'tagId': 'N31MN', 'poleNo': '100022', 'status': 'Printed'},
    {'tagId': 'N31MP', 'poleNo': '100023', 'status': 'Printed'},
    {'tagId': 'M31MQ', 'poleNo': '100024', 'status': 'Printed'},
    {'tagId': 'N31MR', 'poleNo': '100025', 'status': 'Printed'},
    {'tagId': 'N31MS', 'poleNo': '100026', 'status': 'Printed'},
    {'tagId': 'N31MT', 'poleNo': '100027', 'status': 'Printed'},
    {'tagId': 'N31MU', 'poleNo': '100028', 'status': 'Printed'},
    {'tagId': 'N31MV', 'poleNo': '100029', 'status': 'Printed'},
  ];

  int selectedBatchIndex = 1;
  final ScrollController _tagListScrollController = ScrollController();

  @override
  void dispose() {
    _tagListScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedBatch = printedBatches[selectedBatchIndex];

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
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {},
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
                          '1',
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
                          selectedBatch['batchId']!,
                          '${selectedBatch['woRef']} · ${selectedBatch['status']!.toLowerCase()}',
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
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    ...printedBatches.asMap().entries.map(
                                      (entry) {
                                        final i = entry.key;
                                        final batch = entry.value;
                                        final isSelected =
                                            i == selectedBatchIndex;
                                        final isOngoing =
                                            batch['status'] == 'Ongoing';
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
                                                        batch['batchId']!,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        batch['woRef']!,
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
                                                    batch['qty']!,
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
                                                      batch['status']!,
                                                      isOngoing
                                                          ? Colors.orange
                                                          : const Color(
                                                              0xFF1A7A3D),
                                                      isOngoing
                                                          ? Colors.orange[50]!
                                                          : const Color(
                                                              0xFFE7F6EC),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
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
                                          selectedBatch['batchId']!,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${selectedBatch['woRef']!.split(' · ').first} · ${selectedBatch['status']!.toLowerCase()}',
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
                                        selectedBatch['qty']!,
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

                              // Tag table
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
                                      child: Scrollbar(
                                        controller: _tagListScrollController,
                                        thumbVisibility: true,
                                        child: SingleChildScrollView(
                                          controller: _tagListScrollController,
                                          child: Column(
                                            children: selectedBatchTags
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                              final index = entry.key;
                                              final tag = entry.value;
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 12,
                                                ),
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    bottom: BorderSide(
                                                        color:
                                                            Colors.grey[200]!),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 1,
                                                      child: Text(
                                                        '${index + 1}',
                                                        style: const TextStyle(
                                                            fontSize: 13),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 3,
                                                      child: Text(
                                                        tag['tagId']!,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 3,
                                                      child: Text(
                                                        tag['poleNo']!,
                                                        style: const TextStyle(
                                                            fontSize: 13),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: _buildStatusPill(
                                                          tag['status']!,
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
                                      'Count the sheet against the ${selectedBatch['qty']} tag IDs listed above.',
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
