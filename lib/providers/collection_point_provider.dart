import 'package:flutter/material.dart';
import 'dart:async';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/local_database_service.dart';
import '../utils/input_validation.dart';
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
    // Always cancel previous subscription
    _pointsSubscription?.cancel();
    _error = null;

    // Load cached points first to show data immediately
    loadCachedPoints().then((_) {
      // Subscribe to stream for fresh data
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
          debugPrint('Error loading collection points: $e');
          _error = 'Failed to load collection points.';
          notifyListeners();
        },
      );
    });
  }

  // Force refresh collection points from Firestore
  Future<void> refreshCollectionPoints() async {
    try {
      final points = await _firestoreService.getCollectionPoints();
      _points = points;
      _error = null;
      for (final p in points) {
        await _localDb.cacheCollectionPoint(p);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing collection points: $e');
      _error = 'Failed to refresh collection points.';
      notifyListeners();
    }
  }

  Future<void> loadCachedPoints() async {
    _points = await _localDb.getCachedCollectionPoints();
    notifyListeners();
  }

  Future<bool> addCollectionPoint({
    required String name,
    required String address,
    required String region,
    required String ownerAdminId,
    required String ownerAdminName,
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
      if (ownerAdminId.trim().isEmpty) {
        throw ArgumentError('Invalid aggregator account.');
      }
      final cleanName = InputValidation.normalizeText(name);
      final cleanAddress = InputValidation.normalizeText(address);
      final cleanRegion = InputValidation.normalizeText(region);
      final cleanFacilities = InputValidation.normalizeText(facilities);
      final cleanOperatingHours = InputValidation.normalizeText(operatingHours);
      final cleanContactPhone = (contactPhone ?? '').trim();

      final validationErrors = <String?>[
        InputValidation.requiredText(
          cleanName,
          fieldName: 'collection point name',
          maxLength: 100,
        ),
        InputValidation.requiredText(
          cleanAddress,
          fieldName: 'collection point address',
          maxLength: 200,
        ),
        InputValidation.requiredText(
          cleanRegion,
          fieldName: 'collection point region',
          maxLength: 50,
        ),
        InputValidation.optionalText(
          cleanFacilities,
          fieldName: 'Facilities',
          maxLength: 200,
        ),
        InputValidation.operatingHours(cleanOperatingHours),
        InputValidation.optionalTenDigitPhone(
          cleanContactPhone,
          fieldName: 'Contact phone',
        ),
      ];
      String? validationError;
      for (final message in validationErrors) {
        if (message != null) {
          validationError = message;
          break;
        }
      }
      if (validationError != null) {
        throw ArgumentError(validationError);
      }

      final point = CollectionPoint(
        id: _uuid.v4(),
        name: cleanName,
        address: cleanAddress,
        region: cleanRegion,
        ownerAdminId: ownerAdminId.trim(),
        ownerAdminName: ownerAdminName.trim().isEmpty
            ? null
            : InputValidation.normalizeText(ownerAdminName),
        latitude: latitude,
        longitude: longitude,
        facilities: cleanFacilities.isEmpty ? null : cleanFacilities,
        contactPhone: cleanContactPhone.isEmpty ? null : cleanContactPhone,
        operatingHours:
            cleanOperatingHours.isEmpty ? null : cleanOperatingHours,
        isActive: true,
        createdAt: DateTime.now(),
      );
      await _firestoreService.createCollectionPoint(point);
      _points = [..._points.where((p) => p.id != point.id), point];
      await _localDb.cacheCollectionPoint(point);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ArgumentError catch (e) {
      _error = e.message.toString();
      _isLoading = false;
      notifyListeners();
      return false;
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
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return _points;
    return _points
        .where((p) =>
            p.name.toLowerCase().contains(normalizedQuery) ||
            p.region.toLowerCase().contains(normalizedQuery))
        .toList();
  }

  @override
  void dispose() {
    _pointsSubscription?.cancel();
    super.dispose();
  }
}
