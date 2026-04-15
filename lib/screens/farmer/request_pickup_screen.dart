import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/collection_point_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class RequestPickupScreen extends StatefulWidget {
  const RequestPickupScreen({super.key});

  @override
  State<RequestPickupScreen> createState() => _RequestPickupScreenState();
}

class _RequestPickupScreenState extends State<RequestPickupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedProduce;
  CollectionPoint? _selectedPoint;
  DateTime? _selectedDate;
  File? _photoFile;

  final List<String> _produceTypes = [
    'Fruits(eg.Banana)',
    'Vegetables(eg.Tomatoes)',
    'Tubers(eg.Yam)',
    'Grains(eg.Rice)',
    'Legumes(eg.Cowpeas)',
    'Nuts(eg.Cashews)',
    'Seeds(eg.Sunflower)',
    'Herbs(eg.Basil)',
    'Spices(eg.Pepper)',
    'Flowers(eg.Marigold)',
    'Other'
  ];

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked != null) setState(() => _photoFile = File(picked.path));
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a collection point')),
      );
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a preferred pickup date')),
      );
      return;
    }
    if (_selectedPoint!.ownerAdminId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'This collection point is not linked to an aggregator account yet. Please choose another one.'),
        ),
      );
      return;
    }

    final user = context.read<AuthProvider>().currentUser!;
    final parsedQuantity = double.tryParse(_quantityController.text.trim());
    if (parsedQuantity == null || parsedQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive quantity')),
      );
      return;
    }

    final success = await context.read<RequestProvider>().submitRequest(
          farmerId: user.id,
          farmerName: user.fullName,
          farmerPhone: user.phoneNumber,
          aggregatorId: _selectedPoint!.ownerAdminId,
          aggregatorName: _selectedPoint!.ownerAdminName,
          collectionPointId: _selectedPoint!.id,
          collectionPointName: _selectedPoint!.name,
          produceType: _selectedProduce!,
          quantity: parsedQuantity,
          requestedDate: _selectedDate!,
          photoFile: _photoFile,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pickup request submitted successfully!'),
            backgroundColor: AppColors.primary),
      );
      Navigator.pushReplacementNamed(context, AppRoutes.requestStatus);
      return;
    }

    final error = context.read<RequestProvider>().error ??
        'Unable to submit pickup request right now. Please try again.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: AppColors.error),
    );
  }

  Future<void> _pickCollectionPoint() async {
    final provider = context.read<CollectionPointProvider>();
    await provider.loadCachedPoints();
    provider.listenToCollectionPoints();

    if (!mounted) return;

    final selected = await showModalBottomSheet<CollectionPoint>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CollectionPointSelectorSheet(
        initiallySelectedId: _selectedPoint?.id,
      ),
    );

    if (selected != null && mounted) {
      setState(() => _selectedPoint = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestProvider = context.watch<RequestProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Request Pickup')),
      body: LoadingOverlay(
        isLoading: requestProvider.isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel(text: 'Produce Details'),
                DropdownButtonFormField<String>(
                  initialValue: _selectedProduce,
                  decoration: const InputDecoration(
                    labelText: 'Produce Type',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  items: _produceTypes
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedProduce = v),
                  validator: (v) =>
                      v == null ? 'Please select a produce type' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity (kg)',
                    prefixIcon: Icon(Icons.scale_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter the quantity';
                    }
                    final parsed = double.tryParse(v);
                    if (parsed == null) {
                      return 'Please enter a valid number';
                    }
                    if (parsed <= 0) {
                      return 'Quantity must be greater than 0';
                    }
                    if (parsed > 10000) {
                      return 'Quantity cannot exceed 10,000 kg';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                const SectionLabel(text: 'Collection Point'),
                GestureDetector(
                  onTap: _pickCollectionPoint,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(
                          color: _selectedPoint == null
                              ? AppColors.border
                              : AppColors.primary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            color: _selectedPoint != null
                                ? AppColors.primary
                                : AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedPoint?.name ?? 'Select collection point',
                            style: TextStyle(
                                color: _selectedPoint != null
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary),
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const SectionLabel(text: 'Pickup Date'),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(
                          color: _selectedDate == null
                              ? AppColors.border
                              : AppColors.primary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            color: _selectedDate != null
                                ? AppColors.primary
                                : AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Text(
                          _selectedDate != null
                              ? DateFormat('MMM d, yyyy').format(_selectedDate!)
                              : 'Select preferred date',
                          style: TextStyle(
                              color: _selectedDate != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const SectionLabel(text: 'Produce Photo (Optional)'),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(
                          color: AppColors.border, style: BorderStyle.solid),
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
                              Text('Take Photo',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary)),
                              Text('Optional',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                      labelText: 'Additional Notes (Optional)',
                      prefixIcon: Icon(Icons.notes_outlined)),
                  validator: (v) {
                    if (v != null && v.trim().length > 500) {
                      return 'Notes cannot exceed 500 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: requestProvider.isLoading ? null : _submit,
                  child: const Text('Submit Request'),
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

class _CollectionPointSelectorSheet extends StatefulWidget {
  final String? initiallySelectedId;

  const _CollectionPointSelectorSheet({this.initiallySelectedId});

  @override
  State<_CollectionPointSelectorSheet> createState() =>
      _CollectionPointSelectorSheetState();
}

class _CollectionPointSelectorSheetState
    extends State<_CollectionPointSelectorSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CollectionPointProvider>();
    final points = provider
        .search(_query)
        .where((point) => point.ownerAdminId.trim().isNotEmpty)
        .toList();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select Collection Point',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: const InputDecoration(
                  hintText: 'Search by name or region...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              if (provider.error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    provider.error!,
                    style:
                        const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              Expanded(
                child: points.isEmpty
                    ? const EmptyState(
                        icon: Icons.location_off_outlined,
                        title: 'No Collection Points Available',
                        subtitle:
                            'Collection points added by admins will appear here.',
                      )
                    : ListView.separated(
                        itemCount: points.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final point = points[index];
                          final isSelected =
                              point.id == widget.initiallySelectedId;
                          return Card(
                            child: ListTile(
                              onTap: () => Navigator.pop(context, point),
                              leading: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.location_on_outlined,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                              title: Text(point.name),
                              subtitle: Text(point.ownerAdminName
                                          ?.trim()
                                          .isNotEmpty ==
                                      true
                                  ? '${point.region} • ${point.address}\nAggregator: ${point.ownerAdminName}'
                                  : '${point.region} • ${point.address}'),
                              trailing: const Icon(Icons.chevron_right),
                              isThreeLine:
                                  point.ownerAdminName?.trim().isNotEmpty ==
                                      true,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
