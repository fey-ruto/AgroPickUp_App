import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/superadmin/superadmin_provider.dart';
import '../../../utils/app_theme.dart';

class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SuperadminProvider>();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: p.refreshRequests,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionLabel('REQUESTS OVER TIME'),
          const SizedBox(height: 10),
          _MonthlyChart(data: p.requestsByMonth),
          const SizedBox(height: 24),
          _SectionLabel('MOST ACTIVE COLLECTION POINTS'),
          const SizedBox(height: 10),
          _RankList(
            data: p.collectionPointActivity,
            color: AppColors.info,
            icon: Icons.location_on_outlined,
            emptyMsg: 'No collection point data yet',
          ),
          const SizedBox(height: 24),
          _SectionLabel('MOST FREQUENT FARMERS'),
          const SizedBox(height: 10),
          _RankList(
            data: p.farmerRequestFrequency,
            color: AppColors.primary,
            icon: Icons.person_outline,
            emptyMsg: 'No farmer request data yet',
            unit: 'requests',
          ),
          const SizedBox(height: 24),
          _SectionLabel('AVERAGE PRODUCE PER REQUEST'),
          const SizedBox(height: 10),
          _AvgProduceCard(provider: p),
          const SizedBox(height: 24),
          _SectionLabel('PRODUCE TYPE BREAKDOWN'),
          const SizedBox(height: 10),
          _ProducePieList(data: p.produceByType),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  final Map<String, int> data;
  const _MonthlyChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _emptyCard('No monthly data yet');
    }
    final sorted = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxVal = sorted.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Monthly Requests',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontSize: 13)),
                Text('Last ${sorted.length} months',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: sorted.map((e) {
                  final pct = maxVal > 0 ? e.value / maxVal : 0.0;
                  final label = _shortMonth(e.key);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${e.value}',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: pct.clamp(0.04, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(label,
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortMonth(String key) {
    try {
      final parts = key.split('-');
      final month = int.parse(parts[1]);
      const names = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return names[month];
    } catch (_) {
      return key;
    }
  }
}

class _RankList extends StatelessWidget {
  final Map<String, int> data;
  final Color color;
  final IconData icon;
  final String emptyMsg;
  final String unit;

  const _RankList({
    required this.data,
    required this.color,
    required this.icon,
    required this.emptyMsg,
    this.unit = 'requests',
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return _emptyCard(emptyMsg);
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList();
    final maxVal = top.first.value;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: top.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final pct = maxVal > 0 ? e.value / maxVal : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text('${i + 1}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: i == 0
                                ? color
                                : AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 4),
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.key,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor:
                                AppColors.border.withValues(alpha: 0.3),
                            valueColor:
                                AlwaysStoppedAnimation(color),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${e.value} $unit',
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

class _AvgProduceCard extends StatelessWidget {
  final SuperadminProvider provider;
  const _AvgProduceCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final total = provider.totalRequests;
    final weight = provider.totalProduceWeight;
    final avg = total > 0 ? weight / total : 0.0;
    final fmt = NumberFormat('#,##0.00');

    final byType = provider.produceByType;
    final typeAvgs = <String, double>{};
    if (total > 0) {
      for (final e in byType.entries) {
        final typeCount = provider.allRequests
            .where((r) =>
                (r['produceType'] as String? ?? '').trim() == e.key)
            .length;
        if (typeCount > 0) typeAvgs[e.key] = e.value / typeCount;
      }
    }
    final sortedAvg = typeAvgs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.scale_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('${fmt.format(avg)} kg',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              ],
            ),
            Text('Average quantity per pickup request',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            if (sortedAvg.isNotEmpty) ...[
              const Divider(height: 24),
              Text('BY PRODUCE TYPE',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 1.1)),
              const SizedBox(height: 8),
              ...sortedAvg.take(5).map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(e.key,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary))),
                        Text('avg ${fmt.format(e.value)} kg',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProducePieList extends StatelessWidget {
  final Map<String, double> data;
  const _ProducePieList({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return _emptyCard('No produce data yet');
    final total = data.values.fold(0.0, (a, b) => a + b);
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final fmt = NumberFormat('#,##0.0');
    final colors = [
      AppColors.primary,
      AppColors.info,
      AppColors.warning,
      const Color(0xFF6A5ACD),
      const Color(0xFF20B2AA),
      const Color(0xFFDC143C),
      const Color(0xFFFF8C00),
      const Color(0xFF2E8B57),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final pct = total > 0 ? e.value / total : 0.0;
            final color = colors[i % colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.key,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary)),
                  ),
                  Text('${fmt.format(e.value)} kg',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text('${(pct * 100).toStringAsFixed(1)}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color)),
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

Widget _emptyCard(String msg) => Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(msg,
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
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
