// 📁 lib/screens/printerman_screen.dart

import 'package:flutter/material.dart';

class PrinterManScreen extends StatelessWidget {
  const PrinterManScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Hardcoded data
    final List<Map<String, String>> currentBatchTags = const [
      {
        'tagId': 'N31MW',
        'poleNo': '100030',
        'status': 'Available',
        'remarks': '—'
      },
      {
        'tagId': 'N31MY',
        'poleNo': '100031',
        'status': 'Available',
        'remarks': '—'
      },
      {
        'tagId': 'N31NO',
        'poleNo': '100032',
        'status': 'Available',
        'remarks': '—'
      },
      {
        'tagId': 'N31N1',
        'poleNo': '100033',
        'status': 'Available',
        'remarks': '—'
      },
      {
        'tagId': 'N31N3',
        'poleNo': '100035',
        'status': 'Available',
        'remarks': '—'
      },
      {
        'tagId': 'N31N4',
        'poleNo': '100036',
        'status': 'Available',
        'remarks': '—'
      },
      {
        'tagId': 'N31N5',
        'poleNo': '100037',
        'status': 'Available',
        'remarks': '—'
      },
      {
        'tagId': 'N31N6',
        'poleNo': '100038',
        'status': 'Available',
        'remarks': '—'
      },
      {
        'tagId': 'N31N8',
        'poleNo': '100040',
        'status': 'Available',
        'remarks': '—'
      },
      {
        'tagId': 'N31N9',
        'poleNo': '100041',
        'status': 'Available',
        'remarks': '—'
      },
      {
        'tagId': 'N31NA',
        'poleNo': '100042',
        'status': 'Available',
        'remarks': '—'
      },
      {
        'tagId': 'N31NB',
        'poleNo': '100043',
        'status': 'Available',
        'remarks': '—'
      },
    ];

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
                // STAT CARDS - Now stretch to fill width
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
                      '24',
                      'BT-2026-0043 - awaiting print',
                      Icons.production_quantity_limits,
                      Colors.purple,
                    )),
                  ],
                ),

                const SizedBox(height: 32),

                // ============================================================
                // NEW PRINT BATCH - Full width with spaced fields
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
                      // Fields in a row with equal spacing
                      Row(
                        children: [
                          Expanded(
                              child: _buildBatchField(
                                  'DU CODE', 'N – Negros Power')),
                          const SizedBox(width: 24),
                          Expanded(
                              child:
                                  _buildBatchField('BATCH ID', 'BT-2026-0044')),
                          const SizedBox(width: 24),
                          Expanded(
                              child: _buildBatchField(
                                  'WORK ORDER REFERENCE', 'WO-2026-0118')),
                          const SizedBox(width: 24),
                          Expanded(child: _buildBatchField('QUANTITY', '24')),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 160,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A7A3D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Generate batch'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ============================================================
                // CURRENT BATCH - Full width table
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Text(
                              'BT-2025-0043 - WO-2025-0118 - 24 tags - not yet printed',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ============================================================
                      // TABLE - Full width
                      // ============================================================
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
                                  _buildTableHeader('STATUS', flex: 3),
                                  _buildTableHeader('REMARKS', flex: 3),
                                  const SizedBox(
                                    width: 140,
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
                            // Table Rows
                            Column(
                              children:
                                  currentBatchTags.asMap().entries.map((entry) {
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
                                      _buildTableCell(tag['tagId']!,
                                          flex: 3, isBold: true),
                                      _buildTableCell(tag['poleNo']!, flex: 3),
                                      _buildTableCell(tag['status']!,
                                          flex: 3, isStatus: true),
                                      _buildTableCell(tag['remarks']!, flex: 3),
                                      _buildActionButton(),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ============================================================
                      // PAGINATION
                      // ============================================================
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Showing 1-12 of 24 - page 1 of 2',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.chevron_left, color: Colors.grey),
                              SizedBox(width: 8),
                              Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ============================================================
                // FOOTER NOTE
                // ============================================================
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

  // ─── Helper Widgets ───

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
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

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

  Widget _buildActionButton() {
    return SizedBox(
      width: 140,
      child: TextButton(
        onPressed: () {},
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
}
