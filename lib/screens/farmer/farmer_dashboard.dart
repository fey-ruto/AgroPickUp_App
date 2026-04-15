import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/collection_point_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';

class FarmerDashboard extends StatefulWidget {
  const FarmerDashboard({super.key});

  @override
  State<FarmerDashboard> createState() => _FarmerDashboardState();
}

class _FarmerDashboardState extends State<FarmerDashboard> {
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final requestProvider = context.read<RequestProvider>();
    final collectionPointProvider = context.read<CollectionPointProvider>();
    final notificationProvider = context.read<NotificationProvider>();

    // Start listening to all streams
    requestProvider.listenToFarmerRequests(user.id);
    collectionPointProvider.listenToCollectionPoints();
    notificationProvider.listenToNotifications(user.id);

    // Immediately refresh to load existing data from database
    await Future.wait([
      requestProvider.refreshFarmerRequests(user.id),
      collectionPointProvider.refreshCollectionPoints(),
      notificationProvider.refreshNotifications(user.id),
    ]);

    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() => _isOffline = result == ConnectivityResult.none);
    Connectivity().onConnectivityChanged.listen((result) {
      if (!mounted) return;
      final offline = result == ConnectivityResult.none;
      setState(() => _isOffline = offline);
      if (!offline) context.read<RequestProvider>().syncOfflineRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final unreadCount = context.watch<NotificationProvider>().unreadCount;
    final requests = context.watch<RequestProvider>().requests;
    final user = auth.currentUser;
    final latestRequest = requests.isNotEmpty ? requests.first : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmer Dashboard'),
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
          if (_isOffline) const OfflineBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WelcomeCard(name: user?.fullName ?? ''),
                  const SizedBox(height: 20),
                  if (latestRequest != null) ...[
                    const SectionLabel(text: 'Latest Pickup'),
                    _LatestPickupCard(request: latestRequest),
                    const SizedBox(height: 20),
                  ],
                  const SectionLabel(text: 'Quick Actions'),
                  _ActionCard(
                    icon: Icons.local_shipping_outlined,
                    color: AppColors.primary,
                    title: 'Request Pickup',
                    subtitle: 'Schedule a new collection',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.requestPickup),
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    icon: Icons.checklist_outlined,
                    color: AppColors.info,
                    title: 'View Request Status',
                    subtitle: 'Check your pickup requests',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.requestStatus),
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    icon: Icons.report_problem_outlined,
                    color: AppColors.warning,
                    title: 'Report an Issue',
                    subtitle: 'Get help with a problem',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.reportIssue),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String name;
  const _WelcomeCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.person, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Welcome back,',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LatestPickupCard extends StatelessWidget {
  final PickupRequest request;
  const _LatestPickupCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${request.produceType} — ${request.quantity.toStringAsFixed(0)}kg',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                StatusBadge(status: request.status),
              ],
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(request.collectionPointName,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
