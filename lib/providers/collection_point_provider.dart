import 'package:flutter/material.dart';
import 'dart:async';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/local_database_service.dart';
import 'package:uuid/uuid.dart';

class CollectionPointProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final _uuid = const Uuid();
  StreamSubscription<List<CollectionPoint>>? _pointsSubscription;

  List<CollectionPoint> _points = [];
  bool _isLoading = false;
  String? _error;

  List<CollectionPoint> get points => _points;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void listenToCollectionPoints() {
    if (_pointsSubscription != null) return;

    loadCachedPoints();

    _pointsSubscription = _firestoreService.collectionPointsStream().listen(
      (points) {
        _points = points;
        _error = null;
        for (final p in points) {
          _localDb.cacheCollectionPoint(p);
        }
        notifyListeners();
      },
      onError: (e) {
        _error = 'Failed to load collection points.';
        notifyListeners();
      },
    );
  }

  Future<void> loadCachedPoints() async {
    _points = await _localDb.getCachedCollectionPoints();
    notifyListeners();
  }

  Future<bool> addCollectionPoint({
    required String name,
    required String address,
    required String region,
    required double latitude,
    required double longitude,
    String? facilities,
    String? contactPhone,
    String? operatingHours,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final point = CollectionPoint(
        id: _uuid.v4(),
        name: name,
        address: address,
        region: region,
        latitude: latitude,
        longitude: longitude,
        facilities: facilities,
        contactPhone: contactPhone,
        operatingHours: operatingHours,
        isActive: true,
        createdAt: DateTime.now(),
      );
      await _firestoreService.createCollectionPoint(point);
      _points = [..._points.where((p) => p.id != point.id), point];
      await _localDb.cacheCollectionPoint(point);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to create collection point.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> deactivatePoint(String id) async {
    await _firestoreService.updateCollectionPoint(id, {'isActive': false});
  }

  List<CollectionPoint> search(String query) {
    if (query.isEmpty) return _points;
    return _points
        .where((p) =>
            p.name.toLowerCase().contains(query.toLowerCase()) ||
            p.region.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _pointsSubscription?.cancel();
    super.dispose();
  }
}
