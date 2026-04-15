import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/input_validation.dart';

class AdminRequestDetailScreen extends StatefulWidget {
  const AdminRequestDetailScreen({super.key});

  @override
  State<AdminRequestDetailScreen> createState() =>
      _AdminRequestDetailScreenState();
}

class _AdminRequestDetailScreenState extends State<AdminRequestDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adminNotesController = TextEditingController();
  final _driverController = TextEditingController();
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  RequestStatus? _selectedStatus;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialized) return;

    final request = ModalRoute.of(context)!.settings.arguments as PickupRequest;
    _selectedStatus = request.status;
    if (request.adminNotes != null)
      _adminNotesController.text = request.adminNotes!;
    if (request.assignedDriverId != null)
      _driverController.text = request.assignedDriverId!;
    _scheduledDate = request.scheduledDate;
    if (request.scheduledDate != null) {
      _scheduledTime = TimeOfDay.fromDateTime(request.scheduledDate!);
    }
    _isInitialized = true;
  }

  @override
  void dispose() {
    _adminNotesController.dispose();
    _driverController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _scheduledDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() {
        _scheduledDate = date;
        if (_selectedStatus == RequestStatus.accepted ||
            _selectedStatus == RequestStatus.submitted) {
          _selectedStatus = RequestStatus.scheduled;
        }
      });
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (time != null) {
      setState(() {
        _scheduledTime = time;
        if (_selectedStatus == RequestStatus.accepted ||
            _selectedStatus == RequestStatus.submitted) {
          _selectedStatus = RequestStatus.scheduled;
        }
      });
    }
  }

  DateTime? get _combinedScheduledDateTime {
    if (_scheduledDate == null) return null;
    final time = _scheduledTime ?? const TimeOfDay(hour: 8, minute: 0);
    return DateTime(
      _scheduledDate!.year,
      _scheduledDate!.month,
      _scheduledDate!.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _saveChanges(PickupRequest request) async {
    if (_selectedStatus == null) return;
    if (!_formKey.currentState!.validate()) return;

    final driverInput = _driverController.text.trim();
    final notesInput = _adminNotesController.text.trim();

    var statusToSave = _selectedStatus!;
    final hasSchedulingInputs =
        _scheduledDate != null || _scheduledTime != null;

    if (hasSchedulingInputs &&
        (statusToSave == RequestStatus.accepted ||
            statusToSave == RequestStatus.submitted)) {
      statusToSave = RequestStatus.scheduled;
    }

    if (statusToSave == RequestStatus.scheduled &&
        _combinedScheduledDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please set both scheduled date and time.')),
      );
      return;
    }

    final requestProvider = context.read<RequestProvider>();
    final adminPhone = context.read<AuthProvider>().currentUser?.phoneNumber;
    final adminUserId = context.read<AuthProvider>().currentUser?.id;

    if (adminUserId == null || adminUserId != request.aggregatorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'You are not authorized to update this request for another aggregator account.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final success = await requestProvider.updateStatus(
      request.id,
      statusToSave,
      adminNotes: notesInput.isEmpty ? null : notesInput,
      assignedDriverId: driverInput.isEmpty ? null : driverInput,
      scheduledDate: _combinedScheduledDateTime,
      adminContactPhone: adminPhone,
    );

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(requestProvider.error ?? 'Failed to save changes.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Changes saved successfully.'),
            backgroundColor: AppColors.primary),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = ModalRoute.of(context)!.settings.arguments as PickupRequest;
    final requestProvider = context.watch<RequestProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: LoadingOverlay(
        isLoading: requestProvider.isLoading,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: StatusBadge(status: request.status)),
                      const SizedBox(height: 20),
                      const SectionLabel(text: 'Request Information'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _InfoRow(
                                  icon: Icons.person_outlined,
                                  label: 'Farmer',
                                  value: request.farmerName),
                              if (request.farmerPhone != null &&
                                  request.farmerPhone!.isNotEmpty)
                                _InfoRow(
                                    icon: Icons.phone_outlined,
                                    label: 'Farmer Phone',
                                    value: request.farmerPhone!),
                              _InfoRow(
                                  icon: Icons.inventory_2_outlined,
                                  label: 'Produce',
                                  value: request.produceType),
                              _InfoRow(
                                  icon: Icons.scale_outlined,
                                  label: 'Quantity',
                                  value:
                                      '${request.quantity.toStringAsFixed(0)} kg'),
                              _InfoRow(
                                  icon: Icons.location_on_outlined,
                                  label: 'Collection Point',
                                  value: request.collectionPointName),
                              _InfoRow(
                                icon: Icons.calendar_today_outlined,
                                label: 'Requested Date',
                                value: DateFormat('MMM d, yyyy')
                                    .format(request.requestedDate),
                              ),
                              if (request.notes != null &&
                                  request.notes!.isNotEmpty)
                                _InfoRow(
                                    icon: Icons.notes_outlined,
                                    label: 'Farmer Notes',
                                    value: request.notes!),
                            ],
                          ),
                        ),
                      ),
                      if (request.photoUrl != null) ...[
                        const SizedBox(height: 16),
                        const SectionLabel(text: 'Produce Photo'),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            request.photoUrl!,
                            width: double.infinity,
                            height: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                                height: 60,
                                child: Center(
                                    child: Icon(Icons.broken_image_outlined))),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const SectionLabel(text: 'Assignment & Scheduling'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _driverController,
                                textInputAction: TextInputAction.next,
                                maxLength: 40,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(40),
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z0-9\s\-_/]'),
                                  ),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Assign Driver (Name or ID)',
                                  prefixIcon:
                                      Icon(Icons.local_shipping_outlined),
                                ),
                                validator: InputValidation.driverId,
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: _pickDate,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    border: Border.all(
                                        color: _scheduledDate != null
                                            ? AppColors.primary
                                            : AppColors.border),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.event_outlined,
                                        color: _scheduledDate != null
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _scheduledDate != null
                                            ? DateFormat('MMM d, yyyy')
                                                .format(_scheduledDate!)
                                            : 'Set scheduled date',
                                        style: TextStyle(
                                          color: _scheduledDate != null
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: _pickTime,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    border: Border.all(
                                        color: _scheduledTime != null
                                            ? AppColors.primary
                                            : AppColors.border),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.access_time_outlined,
                                        color: _scheduledTime != null
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _scheduledTime != null
                                            ? _scheduledTime!.format(context)
                                            : 'Set scheduled time',
                                        style: TextStyle(
                                          color: _scheduledTime != null
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SectionLabel(text: 'Update Status'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<RequestStatus>(
                                initialValue: _selectedStatus,
                                decoration: const InputDecoration(
                                    labelText: 'Request Status'),
                                items: RequestStatus.values.map((s) {
                                  final labels = {
                                    RequestStatus.submitted: 'Submitted',
                                    RequestStatus.accepted: 'Accepted',
                                    RequestStatus.scheduled: 'Scheduled',
                                    RequestStatus.pickedUp: 'Picked Up',
                                    RequestStatus.completed: 'Completed',
                                    RequestStatus.cancelled: 'Cancelled',
                                  };
                                  return DropdownMenuItem(
                                      value: s, child: Text(labels[s]!));
                                }).toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedStatus = v),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _adminNotesController,
                                maxLength: 1000,
                                maxLines: 3,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(1000),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Admin Notes',
                                  prefixIcon: Icon(Icons.notes_outlined),
                                  alignLabelWithHint: true,
                                ),
                                validator: (v) => InputValidation.optionalText(
                                  v,
                                  fieldName: 'Admin notes',
                                  maxLength: 1000,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: requestProvider.isLoading
                      ? null
                      : () => _saveChanges(request),
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
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
      ),
    );
  }
}
