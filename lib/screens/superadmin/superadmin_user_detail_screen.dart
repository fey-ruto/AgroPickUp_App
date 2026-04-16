import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/superadmin/superadmin_provider.dart';
import '../../utils/app_theme.dart';

class SuperadminUserDetailScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String role;
  final bool startEditing;

  const SuperadminUserDetailScreen({
    super.key,
    required this.user,
    required this.role,
    this.startEditing = false,
  });

  @override
  State<SuperadminUserDetailScreen> createState() =>
      _SuperadminUserDetailScreenState();
}

class _SuperadminUserDetailScreenState
    extends State<SuperadminUserDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _regionCtrl;
  late final TextEditingController _farmCtrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _editing = widget.startEditing;
    _nameCtrl =
        TextEditingController(text: widget.user['fullName'] as String? ?? '');
    _phoneCtrl = TextEditingController(
        text: widget.user['phoneNumber'] as String? ?? '');
    _regionCtrl =
        TextEditingController(text: widget.user['region'] as String? ?? '');
    _farmCtrl =
        TextEditingController(text: widget.user['farmName'] as String? ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _regionCtrl.dispose();
    _farmCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _liveUser(SuperadminProvider p) {
    final id = widget.user['id'] as String;
    final list = widget.role == 'farmer' ? p.farmers : p.aggregators;
    return list.firstWhere((u) => u['id'] == id, orElse: () => widget.user);
  }

  Future<void> _saveEdits() async {
    if (!_formKey.currentState!.validate()) return;
    final p = context.read<SuperadminProvider>();
    final name = _liveUser(p)['fullName'] as String? ?? 'User';
    await p.updateUser(
      widget.user['id'] as String,
      {
        'fullName': _nameCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'region': _regionCtrl.text.trim(),
        if (widget.role == 'farmer') 'farmName': _farmCtrl.text.trim(),
      },
      name,
    );
    if (mounted) setState(() => _editing = false);
  }

  Future<void> _toggleStatus() async {
    final p = context.read<SuperadminProvider>();
    final live = _liveUser(p);
    final current = live['status'] as String? ?? 'active';
    final newStatus = current == 'suspended' ? 'active' : 'suspended';
    final name = live['fullName'] as String? ?? 'User';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(newStatus == 'suspended' ? 'Suspend User' : 'Activate User'),
        content: Text(newStatus == 'suspended'
            ? 'Suspend $name? They will be unable to use the app.'
            : 'Activate $name? They will regain access.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(newStatus == 'suspended' ? 'Suspend' : 'Activate',
                style: TextStyle(
                    color: newStatus == 'suspended'
                        ? AppColors.error
                        : AppColors.primary)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await p.setUserStatus(widget.user['id'] as String, newStatus, name);
      Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    final p = context.read<SuperadminProvider>();
    final name = _liveUser(p)['fullName'] as String? ?? 'User';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
            'Permanently delete $name\'s profile? '
            'This cannot be undone. Their Firebase Auth account will remain.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final ok =
          await p.deleteUser(widget.user['id'] as String, name);
      if (ok && mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SuperadminProvider>();
    final live = _liveUser(p);
    final name = live['fullName'] as String? ?? 'Unknown';
    final status = live['status'] as String? ?? 'active';
    final isSuspended = status == 'suspended';
    final ts = live['createdAt'];
    final joined = ts is Timestamp
        ? DateFormat('MMM d, yyyy').format(ts.toDate())
        : '—';
    final userId = widget.user['id'] as String;
    final requestCount = p.allRequests
        .where((r) => r['farmerId'] == userId)
        .length;
    final totalWeight = p.allRequests
        .where((r) => r['farmerId'] == userId)
        .fold(0.0, (sum, r) {
      final q = r['quantity'];
      return sum + (q is num ? q.toDouble() : 0.0);
    });
    final fmt = NumberFormat('#,##0.0');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_editing ? 'Edit Profile' : name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _editing = true),
            ),
          if (_editing)
            TextButton(
              onPressed: p.isLoading ? null : _saveEdits,
              child: const Text('Save',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: p.isLoading
          ? const Center(
              child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: isSuspended
                                  ? AppColors.error.withValues(alpha: 0.1)
                                  : AppColors.primaryLight,
                              child: Text(
                                name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isSuspended
                                      ? AppColors.error
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(
                                      widget.role == 'farmer'
                                          ? 'Farmer'
                                          : 'Aggregator',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13)),
                                  const SizedBox(height: 4),
                                  _StatusChip(isSuspended: isSuspended),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Activity summary
                    if (widget.role == 'farmer') ...[
                      _SectionLabel('ACTIVITY SUMMARY'),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              _MiniStat(
                                  label: 'Requests',
                                  value: '$requestCount',
                                  icon: Icons.inventory_2_outlined,
                                  color: AppColors.primary),
                              const SizedBox(width: 16),
                              _MiniStat(
                                  label: 'Total Produce',
                                  value: '${fmt.format(totalWeight)} kg',
                                  icon: Icons.scale_outlined,
                                  color: AppColors.info),
                              const SizedBox(width: 16),
                              _MiniStat(
                                  label: 'Registered',
                                  value: joined,
                                  icon: Icons.calendar_today_outlined,
                                  color: AppColors.warning),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    _SectionLabel('PROFILE DETAILS'),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _EditableField(
                              label: 'Full Name',
                              controller: _nameCtrl,
                              editing: _editing,
                              staticValue: name,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Required'
                                      : null,
                            ),
                            const Divider(height: 24),
                            _EditableField(
                              label: 'Phone Number',
                              controller: _phoneCtrl,
                              editing: _editing,
                              staticValue:
                                  live['phoneNumber'] as String? ?? '—',
                              keyboardType: TextInputType.phone,
                            ),
                            const Divider(height: 24),
                            _EditableField(
                              label: 'Region',
                              controller: _regionCtrl,
                              editing: _editing,
                              staticValue: live['region'] as String? ?? '—',
                            ),
                            if (widget.role == 'farmer') ...[
                              const Divider(height: 24),
                              _EditableField(
                                label: 'Farm Name',
                                controller: _farmCtrl,
                                editing: _editing,
                                staticValue:
                                    live['farmName'] as String? ?? '—',
                              ),
                            ],
                            if (!_editing) ...[
                              const Divider(height: 24),
                              _InfoRow(
                                  label: 'User ID',
                                  value: userId),
                              const Divider(height: 24),
                              _InfoRow(
                                  label: 'Registered', value: joined),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (!_editing) ...[
                      _SectionLabel('ACCOUNT ACTIONS'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _toggleStatus,
                              icon: Icon(
                                  isSuspended
                                      ? Icons.check_circle_outline
                                      : Icons.block_outlined,
                                  size: 18),
                              label: Text(isSuspended ? 'Activate' : 'Suspend'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isSuspended
                                    ? AppColors.primary
                                    : AppColors.warning,
                                side: BorderSide(
                                    color: isSuspended
                                        ? AppColors.primary
                                        : AppColors.warning),
                                minimumSize: const Size(0, 46),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _delete,
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Delete'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: BorderSide(color: AppColors.error),
                                minimumSize: const Size(0, 46),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_editing) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton(
                          onPressed: () => setState(() => _editing = false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}

class _EditableField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool editing;
  final String staticValue;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _EditableField({
    required this.label,
    required this.controller,
    required this.editing,
    required this.staticValue,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    if (!editing) {
      return _InfoRow(label: label, value: staticValue);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            isDense: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide:
                    BorderSide(color: AppColors.primary, width: 1.5)),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13, color: AppColors.textPrimary)),
          ),
        ],
      );
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MiniStat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            Text(label,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _StatusChip extends StatelessWidget {
  final bool isSuspended;
  const _StatusChip({required this.isSuspended});

  @override
  Widget build(BuildContext context) => Container(
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
