import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/collection_point_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  CollectionPoint? _selectedPoint;
  LatLng? _userLocation;
  bool _showList = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static const LatLng _ghanaCenter = LatLng(7.9465, -1.0232);

  @override
  void initState() {
    super.initState();
    final provider = context.read<CollectionPointProvider>();
    provider.loadCachedPoints();
    provider.listenToCollectionPoints();
    _getUserLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      final position = await Geolocator.getCurrentPosition();
      setState(
          () => _userLocation = LatLng(position.latitude, position.longitude));
      _mapController.move(_userLocation!, 13);
    } catch (_) {}
  }

  double _distanceTo(CollectionPoint point) {
    if (_userLocation == null) return 0;
    return Geolocator.distanceBetween(
          _userLocation!.latitude,
          _userLocation!.longitude,
          point.latitude,
          point.longitude,
        ) /
        1000;
  }

  void _handleMapTap(LatLng tappedLocation, List<CollectionPoint> points) {
    if (points.isEmpty) {
      setState(() => _selectedPoint = null);
      return;
    }

    CollectionPoint? nearestPoint;
    double nearestDistanceMeters = double.infinity;

    for (final point in points) {
      final distanceMeters = Geolocator.distanceBetween(
        tappedLocation.latitude,
        tappedLocation.longitude,
        point.latitude,
        point.longitude,
      );
      if (distanceMeters < nearestDistanceMeters) {
        nearestDistanceMeters = distanceMeters;
        nearestPoint = point;
      }
    }

    // Require taps to be reasonably close to a marker to avoid accidental selection.
    if (nearestPoint != null && nearestDistanceMeters <= 800) {
      setState(() => _selectedPoint = nearestPoint);
      return;
    }

    setState(() => _selectedPoint = null);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CollectionPointProvider>();
    final points = provider.search(_searchQuery);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection Points'),
        actions: [
          IconButton(
            icon: Icon(_showList ? Icons.map_outlined : Icons.list),
            onPressed: () => setState(() => _showList = !_showList),
          ),
        ],
      ),
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
                        })
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
          Expanded(
            child: _showList
                ? _PointListView(
                    points: points,
                    onSelect: _selectPoint,
                    distanceTo: _distanceTo)
                : Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _userLocation ?? _ghanaCenter,
                          initialZoom: 10,
                          onTap: (_, tappedLocation) =>
                              _handleMapTap(tappedLocation, points),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.agropickup.gh',
                          ),
                          if (_userLocation != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _userLocation!,
                                  width: 24,
                                  height: 24,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.info,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: points
                                .map((point) => Marker(
                                      point: LatLng(
                                          point.latitude, point.longitude),
                                      width: 40,
                                      height: 40,
                                      child: GestureDetector(
                                        onTap: () => setState(
                                            () => _selectedPoint = point),
                                        child: Icon(
                                          Icons.location_on,
                                          color: _selectedPoint?.id == point.id
                                              ? AppColors.error
                                              : AppColors.primary,
                                          size: 40,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                      if (_selectedPoint != null)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _PointBottomCard(
                            point: _selectedPoint!,
                            distance: _distanceTo(_selectedPoint!),
                            onSelect: () => _selectPoint(_selectedPoint!),
                            onDetail: () => Navigator.pushNamed(
                                context, AppRoutes.collectionPointDetail,
                                arguments: _selectedPoint!),
                          ),
                        ),
                      if (points.isEmpty)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Center(
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.94),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 8,
                                        offset: Offset(0, 3)),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_off_outlined,
                                        color: AppColors.textSecondary),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'No collection points available yet.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      provider.error ??
                                          'Please try again later or contact an admin to add points.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12),
                                    ),
                                    const SizedBox(height: 10),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        provider.loadCachedPoints();
                                        provider.listenToCollectionPoints();
                                      },
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _selectPoint(CollectionPoint point) {
    Navigator.pop(context, point);
  }
}

class _PointListView extends StatelessWidget {
  final List<CollectionPoint> points;
  final void Function(CollectionPoint) onSelect;
  final double Function(CollectionPoint) distanceTo;

  const _PointListView(
      {required this.points, required this.onSelect, required this.distanceTo});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const EmptyState(
          icon: Icons.location_off_outlined,
          title: 'No Points Found',
          subtitle: 'Try a different search term.');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: points.length,
      itemBuilder: (context, i) {
        final point = points[i];
        final dist = distanceTo(point);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child:
                    Icon(Icons.location_on_outlined, color: AppColors.primary)),
            title: Text(point.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${point.address} • ${dist.toStringAsFixed(1)} km'),
            trailing: TextButton(
                onPressed: () => onSelect(point), child: const Text('Select')),
          ),
        );
      },
    );
  }
}

class _PointBottomCard extends StatelessWidget {
  final CollectionPoint point;
  final double distance;
  final VoidCallback onSelect;
  final VoidCallback onDetail;

  const _PointBottomCard(
      {required this.point,
      required this.distance,
      required this.onSelect,
      required this.onDetail});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(point.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16))),
              Text('${distance.toStringAsFixed(1)} km away',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Text(point.address,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          if (point.operatingHours != null) ...[
            const SizedBox(height: 4),
            Text(point.operatingHours!,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDetail,
                  child: const Text('View Details'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onSelect,
                  child: const Text('Select This Point'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CollectionPointDetailScreen extends StatelessWidget {
  const CollectionPointDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final point = ModalRoute.of(context)!.settings.arguments as CollectionPoint;

    return Scaffold(
      appBar: AppBar(title: Text(point.name)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 200,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter:
                              LatLng(point.latitude, point.longitude),
                          initialZoom: 14,
                          interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none),
                        ),
                        children: [
                          TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.agropickup.gh'),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(point.latitude, point.longitude),
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.location_on,
                                    color: AppColors.primary, size: 40),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionLabel(text: 'Location Details'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _InfoRow(
                              icon: Icons.location_on_outlined,
                              label: 'Address',
                              value: point.address),
                          _InfoRow(
                              icon: Icons.map_outlined,
                              label: 'Region',
                              value: point.region),
                          if (point.operatingHours != null)
                            _InfoRow(
                                icon: Icons.access_time_outlined,
                                label: 'Operating Hours',
                                value: point.operatingHours!),
                          if (point.facilities != null)
                            _InfoRow(
                                icon: Icons.store_outlined,
                                label: 'Facilities',
                                value: point.facilities!),
                          if (point.contactPhone != null)
                            _InfoRow(
                                icon: Icons.phone_outlined,
                                label: 'Contact',
                                value: point.contactPhone!),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, point),
              child: const Text('Select This Collection Point'),
            ),
          ),
        ],
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
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
