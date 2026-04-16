import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'dart:async';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/local_database_service.dart';
import 'package:uuid/uuid.dart';

class RequestProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final _uuid = const Uuid();
  StreamSubscription<List<PickupRequest>>? _requestsSubscription;

  List<PickupRequest> _requests = [];
  bool _isLoading = false;
  String? _error;

  List<PickupRequest> get requests => _requests;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void listenToFarmerRequests(String farmerId) {
    _requestsSubscription?.cancel();
    _requestsSubscription =
        _firestoreService.farmerRequestsStream(farmerId).listen(
      (requests) {
        _requests = requests;
        _error = null;
        notifyListeners();
      },
      onError: (_) {
        _error = 'Failed to load requests.';
        notifyListeners();
      },
    );
  }

  void listenToAllRequests() {
    _requestsSubscription?.cancel();
    _requestsSubscription = _firestoreService.allRequestsStream().listen(
      (requests) {
        _requests = requests;
        _error = null;
        notifyListeners();
      },
      onError: (_) {
        _error = 'Failed to load requests.';
        notifyListeners();
      },
    );
  }

  Future<bool> submitRequest({
    required String farmerId,
    required String farmerName,
    String? farmerPhone,
    required String collectionPointId,
    required String collectionPointName,
    required String produceType,
    required double quantity,
    required DateTime requestedDate,
    File? photoFile,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final requestId = _uuid.v4();
    String? photoUrl;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity != ConnectivityResult.none;

      if (isOnline && photoFile != null) {
        try {
          photoUrl = await _firestoreService.uploadProducePhoto(
              photoFile, requestId);
          debugPrint('[RequestProvider] Photo URL saved: $photoUrl');
        } on TimeoutException catch (e) {
          debugPrint('[RequestProvider] Photo upload timed out: $e');
          _error = 'Photo upload timed out. Please check your connection and try again.';
          _isLoading = false;
          notifyListeners();
          return false;
        } catch (e) {
          debugPrint('[RequestProvider] Photo upload failed: $e');
          // Surface the actual error so the cause is visible on-screen.
          final msg = e.toString().replaceFirst('Exception: ', '');
          _error = msg.isNotEmpty ? msg : 'Photo upload failed. Please try again.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // Photo URL confirmed present before building request.
      debugPrint('[RequestProvider] Building request — photoUrl=$photoUrl');

      final request = PickupRequest(
        id: requestId,
        farmerId: farmerId,
        farmerName: farmerName,
        farmerPhone: farmerPhone,
        collectionPointId: collectionPointId,
        collectionPointName: collectionPointName,
        produceType: produceType,
        quantity: quantity,
        status: RequestStatus.submitted,
        requestedDate: requestedDate,
        photoUrl: photoUrl,
        notes: notes,
        isSynced: isOnline,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (isOnline) {
        await _firestoreService.submitRequest(request);
      } else {
        await _localDb.insertOrUpdateRequest(request);
      }

      _requests = [request, ..._requests.where((r) => r.id != request.id)];

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[RequestProvider] Request submission failed: $e');
      _error = 'Failed to submit request. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> syncOfflineRequests() async {
    final unsynced = await _localDb.getUnsyncedRequests();
    for (final request in unsynced) {
      try {
        await _firestoreService.submitRequest(request);
        await _localDb.markAsSynced(request.id);
      } catch (_) {}
    }
  }

  Future<bool> updateStatus(
    String requestId,
    RequestStatus status, {
    String? adminNotes,
    String? assignedDriverId,
    DateTime? scheduledDate,
    String? adminContactPhone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _firestoreService.updateRequestStatus(
        requestId,
        status,
        adminNotes: adminNotes,
        assignedDriverId: assignedDriverId,
        scheduledDate: scheduledDate,
        adminContactPhone: adminContactPhone,
      );

      final index = _requests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        _requests[index] = _requests[index].copyWith(
          status: status,
          adminNotes: adminNotes,
          assignedDriverId: assignedDriverId,
          scheduledDate: scheduledDate,
          adminContactPhone: adminContactPhone,
          isSynced: true,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update status.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    super.dispose();
  }
}
