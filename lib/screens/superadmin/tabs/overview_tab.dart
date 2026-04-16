import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/superadmin/superadmin_provider.dart';
import '../../../utils/app_theme.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SuperadminProvider>();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => p.loadDashboardData(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _WelcomeBanner(email: p.superadminEmail ?? ''),
          const SizedBox(height: 20),
          _SectionLabel('PLATFORM OVERVIEW'),
          const SizedBox(height: 10),
          _StatsGrid(provider: p),
          const SizedBox(height: 24),
          _SectionLabel('REQUESTS BY STATUS'),
          const SizedBox(height: 10),
          _StatusBreakdown(statusMap: p.requestsByStatus),
          const SizedBox(height: 24),
          _SectionLabel('PRODUCE BY TYPE (KG)'),
          const SizedBox(height: 10),
          _HorizontalBar(
            data: p.produceByType,
            color: AppColors.primary,
            unit: 'kg',
          ),
          const SizedBox(height: 24),
          _SectionLabel('PRODUCE BY REGION (KG)'),
          const SizedBox(height: 10),
          _HorizontalBar(
            data: p.produceByRegion,
            color: AppColors.info,
            unit: 'kg',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  final String email;
  const _WelcomeBanner({required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Superadmin Console',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 14)),
                Text(email,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final SuperadminProvider provider;
  const _StatsGrid({required this.provider});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.0');
    final items = [
      _StatItem('Farmers', '${provider.totalFarmers}', Icons.person_outline,
          AppColors.primary),
      _StatItem('Aggregators', '${provider.totalAggregators}',
          Icons.local_shipping_outlined, AppColors.info),
      _StatItem('Total Requests', '${provider.totalRequests}',
          Icons.inventory_2_outlined, AppColors.warning),
      _StatItem('Total Produce',
          '${fmt.format(provider.totalProduceWeight)} kg',
          Icons.scale_outlined, const Color(0xFF6A5ACD)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: items
          .map((item) => _StatCard(
                label: item.label,
                value: item.value,
                icon: item.icon,
                color: item.color,
              ))
          .toList(),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 22),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBreakdown extends StatelessWidget {
  final Map<String, int> statusMap;
  const _StatusBreakdown({required this.statusMap});

  static const _labels = {
    'submitted': 'Pending',
    'accepted': 'Accepted',
    'scheduled': 'Scheduled',
    'pickedUp': 'Picked Up',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
  };

  static const _colors = {
    'submitted': AppColors.statusSubmitted,
    'accepted': AppColors.statusAccepted,
    'scheduled': AppColors.statusScheduled,
    'pickedUp': AppColors.statusPickedUp,
    'completed': AppColors.statusCompleted,
    'cancelled': AppColors.statusCancelled,
  };

  @override
  Widget build(BuildContext context) {
    if (statusMap.isEmpty) {
      return _empty('No request data yet');
    }
    final total = statusMap.values.fold(0, (a, b) => a + b);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _labels.entries.map((e) {
            final count = statusMap[e.key] ?? 0;
            final pct = total > 0 ? count / total : 0.0;
            final color = _colors[e.key] ?? AppColors.border;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(e.value,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor:
                            AppColors.border.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text('$count',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _HorizontalBar extends StatelessWidget {
  final Map<String, double> data;
  final Color color;
  final String unit;
  const _HorizontalBar(
      {required this.data, required this.color, required this.unit});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return _empty('No data yet');
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList();
    final maxVal = top.first.value;
    final fmt = NumberFormat('#,##0.0');
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: top.map((e) {
            final pct = maxVal > 0 ? e.value / maxVal : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(e.key,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor:
                            AppColors.border.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${fmt.format(e.value)} $unit',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

Widget _empty(String msg) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(msg,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ),
    );

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          letterSpacing: 1.2,
        ),
      );
}
