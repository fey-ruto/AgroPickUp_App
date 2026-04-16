import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/superadmin/superadmin_provider.dart';
import '../../../utils/app_theme.dart';

class BroadcastTab extends StatefulWidget {
  const BroadcastTab({super.key});

  @override
  State<BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends State<BroadcastTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _targetRole = 'farmer';
  bool _sent = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final p = context.read<SuperadminProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Broadcast'),
        content: Text(
            'Send "${_titleCtrl.text}" to ${_audienceLabel(_targetRole)}?\n\nThis will create a notification for every matching user.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    p.clearError();
    await p.broadcastNotification(
      title: _titleCtrl.text.trim(),
      message: _messageCtrl.text.trim(),
      targetRole: _targetRole,
    );
    if (mounted && p.error == null) {
      setState(() => _sent = true);
      _titleCtrl.clear();
      _messageCtrl.clear();
      Future.delayed(const Duration(seconds: 3),
          () { if (mounted) setState(() => _sent = false); });
    }
  }

  String _audienceLabel(String role) {
    switch (role) {
      case 'farmer': return 'all Farmers';
      case 'admin': return 'all Aggregators';
      default: return 'all Users';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SuperadminProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel('COMPOSE BROADCAST'),
            const SizedBox(height: 12),
            if (_sent) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text('Broadcast sent successfully!',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
            if (p.error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(p.error!,
                            style: TextStyle(color: AppColors.error))),
                  ],
                ),
              ),
            ],
            _FieldLabel('AUDIENCE'),
            const SizedBox(height: 6),
            Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _AudienceTile(
                    value: 'farmer',
                    groupValue: _targetRole,
                    label: 'Farmers',
                    subtitle: '${p.totalFarmers} users',
                    icon: Icons.person_outline,
                    onChanged: (v) => setState(() => _targetRole = v!),
                  ),
                  Divider(height: 1, color: AppColors.border),
                  _AudienceTile(
                    value: 'admin',
                    groupValue: _targetRole,
                    label: 'Aggregators',
                    subtitle: '${p.totalAggregators} users',
                    icon: Icons.local_shipping_outlined,
                    onChanged: (v) => setState(() => _targetRole = v!),
                  ),
                  Divider(height: 1, color: AppColors.border),
                  _AudienceTile(
                    value: 'all',
                    groupValue: _targetRole,
                    label: 'Everyone',
                    subtitle:
                        '${p.totalFarmers + p.totalAggregators} users',
                    icon: Icons.people_outline,
                    onChanged: (v) => setState(() => _targetRole = v!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _FieldLabel('NOTIFICATION TITLE'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titleCtrl,
              maxLength: 80,
              textInputAction: TextInputAction.next,
              decoration: _inputDec('e.g. Important Update'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter a title'
                  : null,
            ),
            const SizedBox(height: 16),
            _FieldLabel('MESSAGE'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _messageCtrl,
              maxLines: 5,
              maxLength: 500,
              textInputAction: TextInputAction.newline,
              decoration: _inputDec(
                  'Write your message here…'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter a message'
                  : null,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: AppColors.warning, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will create an in-app notification for each recipient. '
                      'It does not send push notifications.',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: p.isLoading ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: p.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_outlined, size: 18),
                label: Text(
                    p.isLoading
                        ? 'Sending…'
                        : 'Send to ${_audienceLabel(_targetRole)}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: AppColors.primary, width: 1.5)),
      );
}

class _AudienceTile extends StatelessWidget {
  final String value;
  final String groupValue;
  final String label;
  final String subtitle;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  const _AudienceTile({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return RadioListTile<String>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: AppColors.primary,
      dense: true,
      title: Row(
        children: [
          Icon(icon,
              size: 16,
              color: selected ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  fontSize: 14)),
        ],
      ),
      subtitle: Text(subtitle,
          style: TextStyle(
              fontSize: 11, color: AppColors.textSecondary)),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            letterSpacing: 1.2),
      );
}

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
            letterSpacing: 1.2),
      );
}
