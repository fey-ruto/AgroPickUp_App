import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String? _selectedIssueType;
  File? _photoFile;
  bool _isSubmitting = false;

  final List<String> _issueTypes = [
    'Missed Pickup',
    'Quality Problem',
    'App Bug',
    'Wrong Quantity',
    'Driver Issue',
    'Other',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked != null) setState(() => _photoFile = File(picked.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIssueType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an issue type')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isSubmitting = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Issue report submitted. We will get back to you.'),
        backgroundColor: AppColors.primary,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an Issue')),
      body: LoadingOverlay(
        isLoading: _isSubmitting,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel(text: 'Issue Photo (Optional)'),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _photoFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(_photoFile!, fit: BoxFit.cover),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_outlined,
                                  size: 36, color: AppColors.textSecondary),
                              SizedBox(height: 8),
                              Text(
                                'Take Photo',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary),
                              ),
                              Text(
                                'Show us the problem',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                const SectionLabel(text: 'Issue Type'),
                DropdownButtonFormField<String>(
                  initialValue: _selectedIssueType,
                  decoration:
                      const InputDecoration(labelText: 'Select issue type'),
                  items: _issueTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedIssueType = v),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please select an issue type';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const SectionLabel(text: 'Describe the Issue'),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 6,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    hintText: 'Please tell us what happened...',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.isEmpty) {
                      return 'Please describe the issue';
                    }
                    if (text.length < 10) {
                      return 'Description is too short (minimum 10 characters)';
                    }
                    if (text.length > 2000) {
                      return 'Description cannot exceed 2000 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                const Text(
                  'Be as detailed as possible',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Submit Issue Report'),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.phone_in_talk_outlined, color: AppColors.info),
                      SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need urgent help?',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.info),
                          ),
                          Text(
                            '+233 XX XXX XXXX',
                            style: TextStyle(
                                color: AppColors.info,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () => provider.markAllRead(user!.id),
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
        ],
      ),
      body: _NotificationsList(notifications: notifications),
    );
  }
}

class _NotificationsList extends StatelessWidget {
  final List<AppNotification> notifications;

  const _NotificationsList({
    required this.notifications,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<NotificationProvider>();
    final user = context.read<AuthProvider>().currentUser;
    final isAdmin = user?.role == UserRole.admin;

    if (notifications.isEmpty) {
      return EmptyState(
        icon: Icons.notifications_none_outlined,
        title: 'No Notifications',
        subtitle: 'Updates about your pickup requests will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: notifications.length,
      itemBuilder: (context, i) {
        final notif = notifications[i];
        return _NotificationItem(
          notification: notif,
          onTap: () {
            provider.markRead(notif.id);
            if (notif.requestId != null) {
              Navigator.pushNamed(
                context,
                isAdmin ? AppRoutes.adminDashboard : AppRoutes.requestStatus,
              );
            }
          },
        );
      },
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationItem({required this.notification, required this.onTap});

  Color get _color {
    switch (notification.type) {
      case NotificationType.requestCompleted:
        return AppColors.primary;
      case NotificationType.requestAccepted:
      case NotificationType.requestScheduled:
        return AppColors.warning;
      case NotificationType.requestCancelled:
        return AppColors.error;
      case NotificationType.general:
        return AppColors.textSecondary;
    }
  }

  IconData get _icon {
    switch (notification.type) {
      case NotificationType.requestCompleted:
        return Icons.check_circle_outline;
      case NotificationType.requestAccepted:
        return Icons.thumb_up_outlined;
      case NotificationType.requestScheduled:
        return Icons.event_available_outlined;
      case NotificationType.requestCancelled:
        return Icons.cancel_outlined;
      case NotificationType.general:
        return Icons.info_outline;
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnread ? AppColors.primaryLight : AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isUnread
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _color.withValues(alpha: 0.15),
              child: Icon(_icon, color: _color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight:
                          isUnread ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.message,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(notification.sentAt),
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
