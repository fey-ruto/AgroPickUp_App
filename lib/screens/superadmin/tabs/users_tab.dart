import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/superadmin/superadmin_provider.dart';
import '../../../utils/app_theme.dart';
import '../superadmin_add_aggregator_screen.dart';
import '../superadmin_user_detail_screen.dart';

class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> users) {
    if (_query.isEmpty) return users;
    return users.where((u) {
      final name = (u['fullName'] as String? ?? '').toLowerCase();
      final phone = (u['phoneNumber'] as String? ?? '').toLowerCase();
      final region = (u['region'] as String? ?? '').toLowerCase();
      return name.contains(_query) ||
          phone.contains(_query) ||
          region.contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SuperadminProvider>();
    final farmers = _filter(p.farmers);
    final aggregators = _filter(p.aggregators);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by name, phone or region…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),
        TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'Farmers (${farmers.length})'),
            Tab(text: 'Aggregators (${aggregators.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _UserList(
                users: farmers,
                role: 'farmer',
                onRefresh: p.refreshUsers,
              ),
              _UserList(
                users: aggregators,
                role: 'aggregator',
                onRefresh: p.refreshUsers,
                fab: FloatingActionButton.extended(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: p,
                          child: const SuperadminAddAggregatorScreen(),
                        ),
                      ),
                    );
                  },
                  backgroundColor: AppColors.primary,
                  icon: const Icon(Icons.person_add_outlined,
                      color: Colors.white),
                  label: const Text('Add Aggregator',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UserList extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final String role;
  final Future<void> Function() onRefresh;
  final Widget? fab;

  const _UserList({
    required this.users,
    required this.role,
    required this.onRefresh,
    this.fab,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline, size: 48, color: AppColors.border),
                const SizedBox(height: 12),
                Text('No ${role}s found',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (fab != null)
            Positioned(bottom: 24, right: 16, child: fab!),
        ],
      );
    }
    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.primary,
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: users.length,
            itemBuilder: (ctx, i) => _UserCard(user: users[i], role: role),
          ),
        ),
        if (fab != null)
          Positioned(bottom: 24, right: 16, child: fab!),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String role;
  const _UserCard({required this.user, required this.role});

  @override
  Widget build(BuildContext context) {
    final p = context.read<SuperadminProvider>();
    final name = user['fullName'] as String? ?? 'Unknown';
    final phone = user['phoneNumber'] as String? ?? '—';
    final region = user['region'] as String? ?? '—';
    final status = user['status'] as String? ?? 'active';
    final isSuspended = status == 'suspended';
    final ts = user['createdAt'];
    final joined = ts is Timestamp
        ? DateFormat('MMM d, yyyy').format(ts.toDate())
        : '—';

    // Count this user's requests from provider data
    final userId = user['id'] as String;
    final requestCount = context
        .watch<SuperadminProvider>()
        .allRequests
        .where((r) => r['farmerId'] == userId)
        .length;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: p,
                child: SuperadminUserDetailScreen(
                    user: user, role: role),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isSuspended
                    ? AppColors.error.withValues(alpha: 0.1)
                    : AppColors.primaryLight,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: isSuspended ? AppColors.error : AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  fontSize: 14)),
                        ),
                        _StatusChip(isSuspended: isSuspended),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('$phone · $region',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                        'Joined $joined'
                        '${role == 'farmer' ? ' · $requestCount requests' : ''}',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert,
                    color: AppColors.textSecondary, size: 18),
                onSelected: (action) =>
                    _handleAction(context, action, user, p),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Edit Profile'),
                      ])),
                  PopupMenuItem(
                      value: isSuspended ? 'activate' : 'suspend',
                      child: Row(children: [
                        Icon(
                            isSuspended
                                ? Icons.check_circle_outline
                                : Icons.block_outlined,
                            size: 16),
                        const SizedBox(width: 8),
                        Text(isSuspended ? 'Activate' : 'Suspend'),
                      ])),
                  PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            size: 16, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(color: AppColors.error)),
                      ])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, String action,
      Map<String, dynamic> user, SuperadminProvider p) async {
    final name = user['fullName'] as String? ?? 'User';
    final id = user['id'] as String;
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: p,
              child: SuperadminUserDetailScreen(
                  user: user, role: role, startEditing: true),
            ),
          ),
        );
        break;
      case 'suspend':
        final ok = await _confirm(context,
            'Suspend $name?', 'They will no longer be able to use the app.');
        if (ok) await p.setUserStatus(id, 'suspended', name);
        break;
      case 'activate':
        await p.setUserStatus(id, 'active', name);
        break;
      case 'delete':
        final ok = await _confirm(context, 'Delete $name?',
            'This will permanently remove their profile from Firestore. Their Firebase Auth account will remain.');
        if (ok) await p.deleteUser(id, name);
        break;
    }
  }

  Future<bool> _confirm(
      BuildContext context, String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Confirm',
                    style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _StatusChip extends StatelessWidget {
  final bool isSuspended;
  const _StatusChip({required this.isSuspended});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSuspended
            ? AppColors.error.withValues(alpha: 0.1)
            : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSuspended
              ? AppColors.error.withValues(alpha: 0.4)
              : AppColors.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        isSuspended ? 'Suspended' : 'Active',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isSuspended ? AppColors.error : AppColors.primary,
        ),
      ),
    );
  }
}
