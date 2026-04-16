import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/superadmin/superadmin_provider.dart';
import '../../../utils/app_theme.dart';

class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SuperadminProvider>();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: p.refreshActivityLog,
      child: p.activityLog.isEmpty
          ? ListView(
              children: [
                SizedBox(
                  height: 400,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_outlined,
                            size: 48, color: AppColors.border),
                        const SizedBox(height: 12),
                        Text('No activity recorded yet',
                            style: TextStyle(
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: p.activityLog.length,
              itemBuilder: (ctx, i) {
                final item = p.activityLog[i];
                return _ActivityItem(item: item, isFirst: i == 0);
              },
            ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isFirst;
  const _ActivityItem({required this.item, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    final action = item['action'] as String? ?? '';
    final details = item['details'] as String? ?? '';
    final performedBy = item['performedBy'] as String? ?? '';
    final ts = item['timestamp'];
    final dt = ts is Timestamp ? ts.toDate() : null;
    final timeStr = dt != null
        ? DateFormat('MMM d, yyyy – h:mm a').format(dt)
        : '—';

    final icon = _iconForAction(action);
    final color = _colorForAction(action);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              Expanded(
                child: Container(
                  width: 1.5,
                  color: AppColors.border.withValues(alpha: 0.5),
                  margin: const EdgeInsets.symmetric(vertical: 2),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(action,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textPrimary)),
                      ),
                      if (isFirst)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Latest',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(details,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time_outlined,
                          size: 11, color: AppColors.border),
                      const SizedBox(width: 3),
                      Text(timeStr,
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary)),
                      const SizedBox(width: 8),
                      Icon(Icons.person_outline,
                          size: 11, color: AppColors.border),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(performedBy,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForAction(String action) {
    if (action.contains('login')) return Icons.login_outlined;
    if (action.contains('deleted') || action.contains('delete')) {
      return Icons.delete_outline;
    }
    if (action.contains('suspended') || action.contains('suspend')) {
      return Icons.block_outlined;
    }
    if (action.contains('activated') || action.contains('activate')) {
      return Icons.check_circle_outline;
    }
    if (action.contains('created') || action.contains('create')) {
      return Icons.person_add_outlined;
    }
    if (action.contains('updated') || action.contains('update')) {
      return Icons.edit_outlined;
    }
    if (action.contains('Broadcast') || action.contains('broadcast')) {
      return Icons.campaign_outlined;
    }
    return Icons.history_outlined;
  }

  Color _colorForAction(String action) {
    if (action.contains('delete')) return AppColors.error;
    if (action.contains('suspend')) return AppColors.warning;
    if (action.contains('activate')) return AppColors.primary;
    if (action.contains('created') || action.contains('create')) {
      return AppColors.info;
    }
    if (action.contains('Broadcast') || action.contains('broadcast')) {
      return const Color(0xFF6A5ACD);
    }
    return AppColors.textSecondary;
  }
}
