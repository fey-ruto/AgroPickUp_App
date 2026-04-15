import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/collection_point_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/models.dart';
import '../../services/geocoding_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/input_validation.dart';

class CollectionPointManagementScreen extends StatefulWidget {
  const CollectionPointManagementScreen({super.key});

  @override
  State<CollectionPointManagementScreen> createState() =>
      _CollectionPointManagementScreenState();
}

class _CollectionPointManagementScreenState
    extends State<CollectionPointManagementScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final provider = context.read<CollectionPointProvider>();
    provider.loadCachedPoints();
    provider.listenToCollectionPoints();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CollectionPointProvider>();
    final points = provider.search(_searchQuery);

    return Scaffold(
      appBar: AppBar(title: const Text('Collection Points')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or region...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
          Expanded(
            child: points.isEmpty
                ? EmptyState(
                    icon: Icons.location_off_outlined,
                    title: 'No Collection Points',
                    subtitle:
                        'Add your first collection point using the button below.',
                    actionLabel: 'Add Collection Point',
                    onAction: () => _showAddEditDialog(context),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: points.length,
                    itemBuilder: (context, i) => _CollectionPointCard(
                      point: points[i],
                      onEdit: () =>
                          _showAddEditDialog(context, point: points[i]),
                      onDeactivate: () =>
                          _confirmDeactivate(context, points[i]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _showAddEditDialog(BuildContext context,
      {CollectionPoint? point}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _AddEditPointSheet(point: point),
    );
  }

  Future<void> _confirmDeactivate(
      BuildContext context, CollectionPoint point) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Collection Point'),
        content: Text(
          'Deactivating "${point.name}" will hide it from farmers. Historical data will be preserved. Continue?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<CollectionPointProvider>().deactivatePoint(point.id);
    }
  }
}

class _CollectionPointCard extends StatelessWidget {
  final CollectionPoint point;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  const _CollectionPointCard(
      {required this.point, required this.onEdit, required this.onDeactivate});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: point.isActive ? AppColors.primary : AppColors.border,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(point.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    '${point.region}  •  ${point.address}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (point.facilities != null)
                    Text(
                      point.facilities!,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'deactivate') onDeactivate();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Edit')
                    ])),
                const PopupMenuItem(
                  value: 'deactivate',
                  child: Row(children: [
                    Icon(Icons.block_outlined,
                        size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Deactivate', style: TextStyle(color: AppColors.error))
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddEditPointSheet extends StatefulWidget {
  final CollectionPoint? point;
  const _AddEditPointSheet({this.point});

  @override
  State<_AddEditPointSheet> createState() => _AddEditPointSheetState();
}

class _AddEditPointSheetState extends State<_AddEditPointSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _facilitiesController = TextEditingController();
  final _phoneController = TextEditingController();
  final _hoursController = TextEditingController();
  final GeocodingService _geocodingService = GeocodingService();

  final List<String> _regions = [
    'Greater Accra',
    'Ashanti',
    'Western',
    'Eastern',
    'Central',
    'Northern',
    'Upper East',
    'Upper West',
    'Volta',
    'Brong-Ahafo',
  ];
  String? _selectedRegion;
  bool _isResolvingLocation = false;
  String? _resolvedLocationLabel;

  LatLng? get _previewCoordinates {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  Future<void> _openManualMapPicker() async {
    final selected = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => _ManualCollectionPointPickerScreen(
          initialLocation: _previewCoordinates ?? const LatLng(7.9465, -1.0232),
        ),
      ),
    );

    if (!mounted || selected == null) return;

    setState(() {
      _latController.text = selected.latitude.toStringAsFixed(6);
      _lngController.text = selected.longitude.toStringAsFixed(6);
      _resolvedLocationLabel = null;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.point != null) {
      final p = widget.point!;
      _nameController.text = p.name;
      _addressController.text = p.address;
      _latController.text = p.latitude.toString();
      _lngController.text = p.longitude.toString();
      _facilitiesController.text = p.facilities ?? '';
      _phoneController.text = p.contactPhone ?? '';
      _hoursController.text = p.operatingHours ?? '';
      _selectedRegion = p.region;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _facilitiesController.dispose();
    _phoneController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    var latitude = double.tryParse(_latController.text.trim());
    var longitude = double.tryParse(_lngController.text.trim());

    if (latitude == null || longitude == null) {
      final resolved = await _resolveCoordinates(showSuccessMessage: false);
      if (!resolved) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Could not determine location. Enter address and region, then tap Find Coordinates.'),
            ),
          );
        }
        return;
      }
      latitude = double.tryParse(_latController.text.trim());
      longitude = double.tryParse(_lngController.text.trim());
    }

    if (latitude == null || longitude == null) {
      return;
    }

    final authUser = context.read<AuthProvider>().currentUser;
    if (authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to verify your account. Please log in again.'),
        ),
      );
      return;
    }

    final provider = context.read<CollectionPointProvider>();
    final success = await provider.addCollectionPoint(
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      region: _selectedRegion!,
      ownerAdminId: authUser.id,
      ownerAdminName: authUser.fullName,
      latitude: latitude,
      longitude: longitude,
      facilities: _facilitiesController.text.trim().isEmpty
          ? null
          : _facilitiesController.text.trim(),
      contactPhone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      operatingHours: _hoursController.text.trim().isEmpty
          ? null
          : _hoursController.text.trim(),
    );
    if (success && mounted) {
      Navigator.pop(context);
      return;
    }

    if (mounted) {
      final message = provider.error ??
          'Failed to save this collection point. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<bool> _resolveCoordinates({bool showSuccessMessage = true}) async {
    final pointName = _nameController.text.trim();
    final address = _addressController.text.trim();
    final region = _selectedRegion;

    if (address.isEmpty || region == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please provide address and region first.')),
        );
      }
      return false;
    }

    setState(() {
      _isResolvingLocation = true;
    });

    try {
      final result = await _geocodingService.geocodeCollectionPoint(
        pointName: pointName,
        address: address,
        region: region,
      );

      if (!mounted) return false;

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Address not found. Refine address and try again.')),
        );
        return false;
      }

      setState(() {
        _latController.text = result.latitude.toStringAsFixed(6);
        _lngController.text = result.longitude.toStringAsFixed(6);
        _resolvedLocationLabel = result.displayName;
      });

      if (showSuccessMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Coordinates generated successfully.')),
        );
      }

      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Unable to geocode location right now. Please try again.')),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.point != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEditing ? 'Edit Collection Point' : 'Add Collection Point',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Point Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedRegion,
                decoration: const InputDecoration(labelText: 'Region'),
                items: _regions
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedRegion = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      _isResolvingLocation ? null : () => _resolveCoordinates(),
                  icon: _isResolvingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.travel_explore_outlined),
                  label: Text(_isResolvingLocation
                      ? 'Finding coordinates...'
                      : 'Find Coordinates from Address'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      decoration: const InputDecoration(
                          labelText: 'Latitude (auto-filled)'),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        final parsed = double.tryParse(v);
                        if (parsed == null) return 'Invalid';
                        if (parsed < -90 || parsed > 90) {
                          return 'Range: -90 to 90';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      decoration: const InputDecoration(
                          labelText: 'Longitude (auto-filled)'),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        final parsed = double.tryParse(v);
                        if (parsed == null) return 'Invalid';
                        if (parsed < -180 || parsed > 180) {
                          return 'Range: -180 to 180';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              if (_resolvedLocationLabel != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Matched location: $_resolvedLocationLabel',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
              if (_previewCoordinates != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 180,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: _previewCoordinates!,
                        initialZoom: 14,
                        interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.agropickup.gh',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _previewCoordinates!,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_on,
                                color: AppColors.primary,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openManualMapPicker,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Adjust Pin on Map'),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _facilitiesController,
                  decoration: const InputDecoration(
                      labelText: 'Facilities (e.g. Storage, Cooling)'),
                  maxLength: 200,
                  validator: (v) {
                    if (v != null && v.trim().length > 200) {
                      return 'Facilities cannot exceed 200 characters';
                    }
                    return null;
                  }),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(labelText: 'Contact Phone'),
                validator: InputValidation.optionalTenDigitPhone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _hoursController,
                  decoration:
                      const InputDecoration(labelText: 'Operating Hours'),
                  validator: InputValidation.operatingHours),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _save,
                child:
                    Text(isEditing ? 'Save Changes' : 'Add Collection Point'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualCollectionPointPickerScreen extends StatefulWidget {
  final LatLng initialLocation;

  const _ManualCollectionPointPickerScreen({required this.initialLocation});

  @override
  State<_ManualCollectionPointPickerScreen> createState() =>
      _ManualCollectionPointPickerScreenState();
}

class _ManualCollectionPointPickerScreenState
    extends State<_ManualCollectionPointPickerScreen> {
  late LatLng _selectedLocation;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick Location on Map')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Tap anywhere on the map to move the pin, then use this location.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _selectedLocation,
                initialZoom: 14,
                onTap: (_, point) => setState(() => _selectedLocation = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.agropickup.gh',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation,
                      width: 42,
                      height: 42,
                      child: const Icon(Icons.location_pin,
                          color: AppColors.error, size: 42),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}  Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, _selectedLocation),
                        child: const Text('Use This Location'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
