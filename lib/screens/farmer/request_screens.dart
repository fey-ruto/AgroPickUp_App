import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/request_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class RequestStatusScreen extends StatelessWidget {
  const RequestStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<RequestProvider>().requests;

    return Scaffold(
      appBar: AppBar(title: const Text('Request Status')),
      body: requests.isEmpty
          ? const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No Requests Yet',
              subtitle:
                  'Your pickup requests will appear here once you submit them.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, i) => RequestCard(
                request: requests[i],
                onTap: () => Navigator.pushNamed(
                    context, AppRoutes.requestDetail,
                    arguments: requests[i]),
              ),
            ),
    );
  }
}

class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final request = ModalRoute.of(context)!.settings.arguments as PickupRequest;

    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: StatusBadge(status: request.status)),
            const SizedBox(height: 24),
            const SectionLabel(text: 'Request Information'),
            _DetailCard(
              children: [
                _DetailRow(
                    icon: Icons.inventory_2_outlined,
                    label: 'Produce',
                    value: request.produceType),
                _DetailRow(
                    icon: Icons.scale_outlined,
                    label: 'Quantity',
                    value: '${request.quantity.toStringAsFixed(0)} kg'),
                _DetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Collection Point',
                    value: request.collectionPointName),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Requested Date',
                  value:
                      DateFormat('MMM d, yyyy').format(request.requestedDate),
                ),
                if (request.scheduledDate != null)
                  _DetailRow(
                    icon: Icons.event_available_outlined,
                    label: 'Scheduled Date',
                    value: DateFormat('MMM d, yyyy – h:mm a')
                        .format(request.scheduledDate!),
                  ),
                if (request.assignedDriverId != null)
                  _DetailRow(
                      icon: Icons.person_outlined,
                      label: 'Assigned Driver',
                      value: request.assignedDriverId!),
                if (request.adminContactPhone != null &&
                    request.adminContactPhone!.isNotEmpty)
                  _DetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Aggregator Phone',
                      value: request.adminContactPhone!),
                if (request.notes != null && request.notes!.isNotEmpty)
                  _DetailRow(
                      icon: Icons.notes_outlined,
                      label: 'Your Notes',
                      value: request.notes!),
                if (request.adminNotes != null &&
                    request.adminNotes!.isNotEmpty)
                  _DetailRow(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Admin Notes',
                      value: request.adminNotes!),
              ],
            ),
            if (request.photoUrl != null) ...[
              const SizedBox(height: 20),
              const SectionLabel(text: 'Produce Photo'),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  request.photoUrl!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                      height: 80,
                      child: Center(child: Icon(Icons.broken_image_outlined))),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const SectionLabel(text: 'Status Timeline'),
            _StatusTimeline(currentStatus: request.status),
            if (request.status == RequestStatus.submitted ||
                request.status == RequestStatus.accepted) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => _confirmCancel(context, request),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                child: const Text('Cancel Request'),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(
      BuildContext context, PickupRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Request'),
        content:
            const Text('Are you sure you want to cancel this pickup request?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep It')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context
          .read<RequestProvider>()
          .updateStatus(request.id, RequestStatus.cancelled);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: children
              .map((child) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: child,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final RequestStatus currentStatus;

  const _StatusTimeline({required this.currentStatus});

  static const _steps = [
    (RequestStatus.submitted, 'Pending'),
    (RequestStatus.accepted, 'Accepted'),
    (RequestStatus.scheduled, 'Scheduled'),
    (RequestStatus.pickedUp, 'Picked Up'),
    (RequestStatus.completed, 'Completed'),
  ];

  @override
  Widget build(BuildContext context) {
    const allStatuses = RequestStatus.values;
    final currentIndex = allStatuses.indexOf(currentStatus);
    final isCancelled = currentStatus == RequestStatus.cancelled;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isCancelled
            ? const Row(
                children: [
                  Icon(Icons.cancel_outlined, color: AppColors.statusCancelled),
                  SizedBox(width: 8),
                  Text('Request Cancelled',
                      style: TextStyle(
                          color: AppColors.statusCancelled,
                          fontWeight: FontWeight.bold)),
                ],
              )
            : Column(
                children: _steps.asMap().entries.map((entry) {
                  final index = entry.key;
                  final (status, label) = entry.value;
                  final isDone = allStatuses.indexOf(status) <= currentIndex;
                  final isCurrent = status == currentStatus;

                  return Row(
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color:
                                  isDone ? AppColors.primary : AppColors.border,
                              shape: BoxShape.circle,
                            ),
                            child: isDone
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 14)
                                : null,
                          ),
                          if (index < _steps.length - 1)
                            Container(
                                width: 2,
                                height: 28,
                                color: isDone
                                    ? AppColors.primary
                                    : AppColors.border),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontWeight:
                                isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isDone
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(growable: false),
              ),
      ),
    );
  }
}
