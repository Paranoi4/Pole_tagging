// 📁 lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/providers/auth_providers.dart';
import 'package:frontend/widgets/add_crew_dialog.dart'; // ✅ ADD THIS LINE

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Hardcoded data for the dashboard
  final List<Map<String, String>> batches = const [
    {
      'batchId': 'BT-N-2026-0041',
      'workOrder': 'WO-N-2026-0118',
      'assignedTo': 'R. Villanueva',
      'qty': '10',
      'used': '0',
      'status': 'Ongoing',
      'statusColor': '#F59E0B',
    },
    {
      'batchId': 'BT-N-2026-0042',
      'workOrder': 'WO-N-2026-0121',
      'assignedTo': '–',
      'qty': '12',
      'used': '0',
      'status': 'Available',
      'statusColor': '#10B981',
    },
    {
      'batchId': 'BT-N-2026-0043',
      'workOrder': 'WO-N-2026-0124',
      'assignedTo': 'J. Estrella',
      'qty': '6',
      'used': '0',
      'status': 'Assigned',
      'statusColor': '#3B82F6',
    },
  ];

  final List<Map<String, String>> tagPool = const [
    {
      'tagId': 'N0000',
      'poleNo': '0',
      'status': 'Available',
      'batch': '–',
      'workOrder': '–',
      'remarks': '–',
      'updated': '–'
    },
    {
      'tagId': 'N0001',
      'poleNo': '1',
      'status': 'Available',
      'batch': '–',
      'workOrder': '–',
      'remarks': '–',
      'updated': '–'
    },
    {
      'tagId': 'N0002',
      'poleNo': '2',
      'status': 'Available',
      'batch': '–',
      'workOrder': '–',
      'remarks': '–',
      'updated': '–'
    },
    {
      'tagId': 'N0003',
      'poleNo': '3',
      'status': 'Available',
      'batch': '–',
      'workOrder': '–',
      'remarks': '–',
      'updated': '–'
    },
    {
      'tagId': 'N0004',
      'poleNo': '4',
      'status': 'Available',
      'batch': '–',
      'workOrder': '–',
      'remarks': '–',
      'updated': '–'
    },
    {
      'tagId': 'N0005',
      'poleNo': '5',
      'status': 'Available',
      'batch': '–',
      'workOrder': '–',
      'remarks': '–',
      'updated': '–'
    },
    {
      'tagId': 'N0006',
      'poleNo': '6',
      'status': 'Available',
      'batch': '–',
      'workOrder': '–',
      'remarks': '–',
      'updated': '–'
    },
    {
      'tagId': 'N0007',
      'poleNo': '7',
      'status': 'Available',
      'batch': '–',
      'workOrder': '–',
      'remarks': '–',
      'updated': '–'
    },
    {
      'tagId': 'N0008',
      'poleNo': '8',
      'status': 'Available',
      'batch': '–',
      'workOrder': '–',
      'remarks': '–',
      'updated': '–'
    },
    {
      'tagId': 'N0009',
      'poleNo': '9',
      'status': 'Available',
      'batch': '–',
      'workOrder': '–',
      'remarks': '–',
      'updated': '–'
    },
    {
      'tagId': 'N0010A',
      'poleNo': '10',
      'status': 'Available',
      'batch': '–',
      'workOrder': '–',
      'remarks': '–',
      'updated': '–'
    },
    {
      'tagId': 'N0011B',
      'poleNo': '11',
      'status': 'Available',
      'batch': '–',
      'workOrder': '–',
      'remarks': '–',
      'updated': '–'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final roleNames = user?.roles.map((r) => r.roleName).toSet() ?? {};
    final isAdmin = roleNames.contains('Admin');
    final isPrinterman = roleNames.contains('Printerman');
    final isDispatcher = roleNames.contains('Dispatcher');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: false,
        actions: [
          if (isPrinterman)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Printerman',
              onPressed: () => context.push('/printerman'),
            ),
          if (isDispatcher)
            IconButton(
              icon: const Icon(Icons.local_shipping),
              tooltip: 'Dispatcher',
              onPressed: () => context.push('/dispatcher'),
            ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
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
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF1A7A3D),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    user?.fullName ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user?.username ?? '',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard, color: Color(0xFF1A7A3D)),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            if (isAdmin) ...[
              ListTile(
                leading: const Icon(Icons.people, color: Color(0xFF1A7A3D)),
                title: const Text('Users'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/users');
                },
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings,
                    color: Color(0xFF1A7A3D)),
                title: const Text('Roles'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/roles');
                },
              ),
            ],
            if (isPrinterman)
              ListTile(
                leading: const Icon(Icons.print, color: Color(0xFF1A7A3D)),
                title: const Text('Printerman'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/printerman');
                },
              ),
            if (isDispatcher)
              ListTile(
                leading:
                    const Icon(Icons.local_shipping, color: Color(0xFF1A7A3D)),
                title: const Text('Dispatcher'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/dispatcher');
                },
              ),
            ListTile(
              leading: const Icon(Icons.person, color: Color(0xFF1A7A3D)),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                context.push('/profile');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
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
                        'PRINTED',
                        '11',
                        'tag IDs',
                        Icons.print,
                        const Color(0xFF1A7A3D),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'DISPATCHED',
                        '14',
                        'tag IDs',
                        Icons.local_shipping,
                        const Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'USED',
                        '8',
                        'tag IDs',
                        Icons.check_circle,
                        const Color(0xFF8B5CF6),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'DO NOT USE',
                        '1',
                        'tag ID',
                        Icons.warning_amber_rounded,
                        const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'LOST PRINTED',
                        '1',
                        'tag ID',
                        Icons.error_outline,
                        const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'BATCHES',
                        '3',
                        'batches',
                        Icons.inventory_2,
                        const Color(0xFFEC4899),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ============================================================
                // TAG ID ADMINISTRATION
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
                        'Tag ID administration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Override any tag or batch status, and release lost or jammed prints.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAdminCard(
                              'ID picker',
                              Icons.qr_code_scanner,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildAdminCard(
                              'Reprint',
                              Icons.print,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ============================================================
                // BATCHES & POOL + ALL BATCHES
                // ============================================================
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT: Batches & pool navigation
                    Expanded(
                      flex: 4,
                      child: Container(
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
                              'Batches & pool',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildNavTile(
                              Icons.people,
                              'Crew',
                              'Manage field crews and assignments',
                              onTap: () => showAddCrewDialog(context),
                            ),
                            _buildNavTile(
                              Icons.assignment,
                              'QC review',
                              'Quality control and verification',
                              onTap: () {},
                            ),
                            _buildNavTile(
                              Icons.history,
                              'Audit trail',
                              'View all system activities',
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // RIGHT: All batches table
                    Expanded(
                      flex: 8,
                      child: Container(
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
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'All batches',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '3 batches across all work orders',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
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
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                        topRight: Radius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildTableHeader('BATCH ID', flex: 2),
                                        _buildTableHeader('WORK ORDER',
                                            flex: 2),
                                        _buildTableHeader('ASSIGNED TO',
                                            flex: 2),
                                        _buildTableHeader('QTY',
                                            flex: 1,
                                            alignment: TextAlign.center),
                                        _buildTableHeader('USED',
                                            flex: 1,
                                            alignment: TextAlign.center),
                                        _buildTableHeader('STATUS',
                                            flex: 2,
                                            alignment: TextAlign.right),
                                      ],
                                    ),
                                  ),
                                  // Table rows
                                  ...batches.map((batch) {
                                    final statusColor = Color(int.parse(
                                        batch['statusColor']!
                                            .replaceFirst('#', '0xFF')));
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
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
                                          _buildTableCell(batch['batchId']!,
                                              flex: 2, isBold: true),
                                          _buildTableCell(batch['workOrder']!,
                                              flex: 2),
                                          _buildTableCell(batch['assignedTo']!,
                                              flex: 2),
                                          _buildTableCell(batch['qty']!,
                                              flex: 1,
                                              alignment: TextAlign.center),
                                          _buildTableCell(batch['used']!,
                                              flex: 1,
                                              alignment: TextAlign.center),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: _buildStatusPill(
                                                batch['status']!,
                                                statusColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ============================================================
                // PRE-GENERATED TAG ID POOL
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pre-generated tag ID pool',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'SERVICE: SERVER',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[700],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '3,145,728 tag IDs on server - Synced 07:11:46 AM',
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
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildTableHeader('TAG ID', flex: 2),
                                  _buildTableHeader('POLE NO.', flex: 2),
                                  _buildTableHeader('STATUS', flex: 2),
                                  _buildTableHeader('BATCH', flex: 2),
                                  _buildTableHeader('WORK ORDER', flex: 2),
                                  _buildTableHeader('REMARKS', flex: 2),
                                  _buildTableHeader('UPDATED',
                                      flex: 2, alignment: TextAlign.right),
                                ],
                              ),
                            ),
                            // Table rows
                            ...tagPool.take(12).map((tag) {
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
                                    _buildTableCell(tag['tagId']!,
                                        flex: 2, isBold: true),
                                    _buildTableCell(tag['poleNo']!, flex: 2),
                                    Expanded(
                                      flex: 2,
                                      child: _buildStatusPill(
                                        tag['status']!,
                                        const Color(0xFF10B981),
                                        small: true,
                                      ),
                                    ),
                                    _buildTableCell(tag['batch']!, flex: 2),
                                    _buildTableCell(tag['workOrder']!, flex: 2),
                                    _buildTableCell(tag['remarks']!, flex: 2),
                                    _buildTableCell(tag['updated']!,
                                        flex: 2, alignment: TextAlign.right),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Pagination
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Showing 1–12 of 3,145,728 · page 1 of 262,144',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.chevron_left,
                                        size: 20, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Previous',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Next',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right,
                                        size: 20, color: Colors.grey),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  children: [
                                    Text('10'),
                                    Icon(Icons.arrow_drop_down, size: 20),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
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
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(String title, IconData icon, Color color) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTile(IconData icon, String title, String subtitle,
      {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Icon(icon, color: const Color(0xFF1A7A3D), size: 24),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[500],
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
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
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildTableCell(
    String text, {
    int flex = 1,
    bool isBold = false,
    TextAlign alignment = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: alignment,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          color: text == '–' ? Colors.grey[400] : null,
        ),
      ),
    );
  }

  Widget _buildStatusPill(
    String text,
    Color color, {
    bool small = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
