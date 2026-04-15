import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _filterStatus = 'All';
  final List<String> _filters = [
    'All',
    'Submitted',
    'Accepted',
    'Scheduled',
    'Picked Up',
    'Completed',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      final requestProvider = context.read<RequestProvider>();
      final notificationProvider = context.read<NotificationProvider>();

      // Start listening to streams
      requestProvider.listenToAggregatorRequests(user.id);
      notificationProvider.listenToNotifications(user.id);

      // Immediately refresh to load existing data from database
      _loadData(user.id, requestProvider, notificationProvider);
    }
  }

  Future<void> _loadData(
    String userId,
    RequestProvider requestProvider,
    NotificationProvider notificationProvider,
  ) async {
    await Future.wait([
      requestProvider.refreshAggregatorRequests(userId),
      notificationProvider.refreshNotifications(userId),
    ]);
  }

  List<PickupRequest> _filteredRequests(List<PickupRequest> requests) {
    if (_filterStatus == 'All') return requests;
    return requests.where((r) {
      switch (_filterStatus) {
        case 'Submitted':
          return r.status == RequestStatus.submitted;
        case 'Accepted':
          return r.status == RequestStatus.accepted;
        case 'Scheduled':
          return r.status == RequestStatus.scheduled;
        case 'Completed':
          return r.status == RequestStatus.completed;
        case 'Picked Up':
          return r.status == RequestStatus.pickedUp;
        case 'Cancelled':
          return r.status == RequestStatus.cancelled;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final unreadCount = context.watch<NotificationProvider>().unreadCount;
    final requestProvider = context.watch<RequestProvider>();
    final allRequests = requestProvider.requests;
    final filtered = _filteredRequests(allRequests);

    final activeCount = allRequests
        .where((r) =>
            r.status == RequestStatus.submitted ||
            r.status == RequestStatus.accepted ||
            r.status == RequestStatus.scheduled)
        .length;
    final completedToday = allRequests
        .where((r) =>
            r.status == RequestStatus.completed &&
            DateUtils.isSameDay(r.updatedAt, DateTime.now()))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aggregator Dashboard'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.notifications),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            onPressed: () => Navigator.pushNamed(
                context, AppRoutes.collectionPointManagement),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              context.read<NotificationProvider>().clearState();
              await auth.logout();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _AdminHeader(user: auth.currentUser),
          _StatsRow(activeCount: activeCount, completedToday: completedToday),
          _FilterRow(
            selected: _filterStatus,
            filters: _filters,
            onSelect: (f) => setState(() => _filterStatus = f),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No Requests',
                    subtitle: 'No pickup requests match the current filter.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _AdminRequestCard(
                      request: filtered[i],
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.adminRequestDetail,
                        arguments: filtered[i],
                      ),
                      onAccept: filtered[i].status == RequestStatus.submitted
                          ? () => _updateStatus(
                              context, filtered[i], RequestStatus.accepted)
                          : null,
                      onDecline: filtered[i].status == RequestStatus.submitted
                          ? () => _confirmDecline(context, filtered[i])
                          : null,
                      onSchedule: filtered[i].status == RequestStatus.accepted
                          ? () => Navigator.pushNamed(
                              context, AppRoutes.adminRequestDetail,
                              arguments: filtered[i])
                          : null,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    PickupRequest request,
    RequestStatus status,
  ) async {
    final requestProvider = context.read<RequestProvider>();
    final adminPhone = context.read<AuthProvider>().currentUser?.phoneNumber;
    final adminUserId = context.read<AuthProvider>().currentUser?.id;
    if (adminUserId == null || adminUserId != request.aggregatorId) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'You are not authorized to update this request for another aggregator account.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final success = await requestProvider.updateStatus(
      request.id,
      status,
      adminContactPhone: adminPhone,
    );
    if (!success) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(requestProvider.error ?? 'Failed to update request.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

  }

  Future<void> _confirmDecline(
      BuildContext context, PickupRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Request'),
        content: Text(
            'Decline the ${request.produceType} pickup request from ${request.farmerName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _updateStatus(context, request, RequestStatus.cancelled);
    }
  }
}

class _AdminHeader extends StatelessWidget {
  final AppUser? user;
  const _AdminHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.primaryLight,
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.admin_panel_settings_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Welcome Back,',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(
                user?.fullName ?? 'Administrator',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int activeCount;
  final int completedToday;

  const _StatsRow({required this.activeCount, required this.completedToday});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Active Requests',
              value: activeCount.toString(),
              color: AppColors.primary,
              icon: Icons.pending_actions_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'Completed Today',
              value: completedToday.toString(),
              color: AppColors.info,
              icon: Icons.check_circle_outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String selected;
  final List<String> filters;
  final void Function(String) onSelect;

  const _FilterRow(
      {required this.selected, required this.filters, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = filters[i];
          final isSelected = f == selected;
          return GestureDetector(
            onTap: () => onSelect(f),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border),
              ),
              child: Text(
                f,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AdminRequestCard extends StatelessWidget {
  final PickupRequest request;
  final VoidCallback onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onSchedule;

  bool get _hasPhoto =>
      request.photoUrl != null && request.photoUrl!.trim().isNotEmpty;

  const _AdminRequestCard({
    required this.request,
    required this.onTap,
    this.onAccept,
    this.onDecline,
    this.onSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${request.produceType}  •  ${request.quantity.toStringAsFixed(0)}kg',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  StatusBadge(status: request.status),
                ],
              ),
              if (_hasPhoto) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    request.photoUrl!,
                    width: double.infinity,
                    height: 130,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: double.infinity,
                        height: 130,
                        color: AppColors.surface,
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      width: double.infinity,
                      height: 130,
                      color: AppColors.surface,
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_outlined,
                              color: AppColors.textSecondary, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Image unavailable',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Farmer: ${request.farmerName}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      request.collectionPointName,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM d, yyyy').format(request.requestedDate),
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              if (onAccept != null ||
                  onDecline != null ||
                  onSchedule != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                if (onAccept != null && onDecline != null)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onAccept,
                          child: const Text('Accept'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onDecline,
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error)),
                          child: const Text('Decline'),
                        ),
                      ),
                    ],
                  ),
                if (onSchedule != null)
                  ElevatedButton(
                    onPressed: onSchedule,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.info),
                    child: const Text('Schedule Pickup'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
