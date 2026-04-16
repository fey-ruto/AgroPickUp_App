import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/superadmin/superadmin_provider.dart';
import '../../utils/app_theme.dart';
import 'tabs/overview_tab.dart';
import 'tabs/users_tab.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/activity_tab.dart';
import 'tabs/broadcast_tab.dart';

class SuperadminShell extends StatefulWidget {
  const SuperadminShell({super.key});

  @override
  State<SuperadminShell> createState() => _SuperadminShellState();
}

class _SuperadminShellState extends State<SuperadminShell> {
  int _selectedIndex = 0;

  static const _tabs = [
    OverviewTab(),
    UsersTab(),
    AnalyticsTab(),
    ActivityTab(),
    BroadcastTab(),
  ];

  static const _labels = [
    'Overview',
    'Users',
    'Analytics',
    'Activity',
    'Broadcast',
  ];

  static const _icons = [
    Icons.dashboard_outlined,
    Icons.people_outline,
    Icons.bar_chart_outlined,
    Icons.history_outlined,
    Icons.campaign_outlined,
  ];

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of the superadmin portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<SuperadminProvider>().logout();
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SuperadminProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _labels[_selectedIndex],
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: const Icon(Icons.refresh_outlined),
              tooltip: 'Refresh',
              onPressed: provider.isLoading
                  ? null
                  : () => provider.loadDashboardData(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.logout_outlined),
              tooltip: 'Sign Out',
              onPressed: _logout,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: provider.isLoading
              ? LinearProgressIndicator(
                  backgroundColor: AppColors.primary,
                  color: Colors.white.withValues(alpha: 0.6),
                  minHeight: 2,
                )
              : const SizedBox(height: 1),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: List.generate(
          _labels.length,
          (i) => BottomNavigationBarItem(
            icon: Icon(_icons[i]),
            label: _labels[i],
          ),
        ),
      ),
    );
  }
}
