import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:async';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/local_database_service.dart';
import '../utils/input_validation.dart';
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
    if (farmerId.trim().isEmpty) {
      _requests = [];
      _error = null;
      notifyListeners();
      return;
    }
    _requestsSubscription?.cancel();
    _error = null;

    // Load initial data and then subscribe for real-time updates
    _firestoreService.getFarmerRequests(farmerId).then((requests) {
      _requests = requests;
      notifyListeners();

      // Now subscribe to stream for real-time updates
      _requestsSubscription =
          _firestoreService.farmerRequestsStream(farmerId).listen(
        (requests) {
          _requests = requests;
          _error = null;
          notifyListeners();
        },
        onError: (_) {
          debugPrint('Error loading farmer requests: $_');
          _error = 'Failed to load requests.';
          notifyListeners();
        },
      );
    }).catchError((e) {
      debugPrint('Error loading initial farmer requests: $e');
      _error = 'Failed to load requests.';
      notifyListeners();
    });
  }

  Future<void> refreshFarmerRequests(String farmerId) async {
    if (farmerId.trim().isEmpty) return;
    try {
      final requests = await _firestoreService.getFarmerRequests(farmerId);
      _requests = requests;
      _error = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing farmer requests: $e');
      _error = 'Failed to refresh requests.';
      notifyListeners();
    }
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

  void listenToAggregatorRequests(String aggregatorId) {
    if (aggregatorId.trim().isEmpty) {
      _requests = [];
      _error = null;
      notifyListeners();
      return;
    }
    _requestsSubscription?.cancel();
    _error = null;

    // Load initial data and then subscribe for real-time updates
    _firestoreService.getAggregatorRequests(aggregatorId).then((requests) {
      _requests = requests;
      notifyListeners();

      // Now subscribe to stream for real-time updates
      _requestsSubscription =
          _firestoreService.aggregatorRequestsStream(aggregatorId).listen(
        (requests) {
          _requests = requests;
          _error = null;
          notifyListeners();
        },
        onError: (_) {
          debugPrint('Error loading aggregator requests: $_');
          _error = 'Failed to load your assigned requests.';
          notifyListeners();
        },
      );
    }).catchError((e) {
      debugPrint('Error loading initial aggregator requests: $e');
      _error = 'Failed to load your assigned requests.';
      notifyListeners();
    });
  }

  Future<void> refreshAggregatorRequests(String aggregatorId) async {
    if (aggregatorId.trim().isEmpty) return;
    try {
      final requests =
          await _firestoreService.getAggregatorRequests(aggregatorId);
      _requests = requests;
      _error = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing aggregator requests: $e');
      _error = 'Failed to refresh requests.';
      notifyListeners();
    }
  }

  Future<bool> submitRequest({
    required String farmerId,
    required String farmerName,
    String? farmerPhone,
    required String aggregatorId,
    String? aggregatorName,
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
      final cleanFarmerId = farmerId.trim();
      final cleanFarmerName = InputValidation.normalizeText(farmerName);
      final cleanAggregatorId = aggregatorId.trim();
      final cleanProduceType = InputValidation.normalizeText(produceType);
      final cleanCollectionPointId = collectionPointId.trim();
      final cleanCollectionPointName =
          InputValidation.normalizeText(collectionPointName);
      final cleanNotes = InputValidation.normalizeText(notes);
      final cleanFarmerPhone = (farmerPhone ?? '').trim();

      if (cleanFarmerId.isEmpty || cleanFarmerName.isEmpty) {
        throw ArgumentError(
            'Invalid farmer account data. Please log in again.');
      }
      if (cleanAggregatorId.isEmpty) {
        throw ArgumentError(
            'This collection point is not linked to an aggregator account yet. Please choose another point.');
      }
      if (cleanCollectionPointId.isEmpty || cleanCollectionPointName.isEmpty) {
        throw ArgumentError('Invalid collection point selection.');
      }
      if (cleanProduceType.isEmpty) {
        throw ArgumentError('Please select a valid produce type.');
      }
      if (quantity <= 0 || quantity > 10000) {
        throw ArgumentError('Quantity must be between 1 and 10,000 kg.');
      }
      final farmerPhoneError = InputValidation.optionalTenDigitPhone(
        cleanFarmerPhone,
        fieldName: 'Farmer phone',
      );
      if (farmerPhoneError != null) {
        throw ArgumentError(farmerPhoneError);
      }
      if (cleanNotes.isNotEmpty && cleanNotes.length > 500) {
        throw ArgumentError('Additional notes cannot exceed 500 characters.');
      }

      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity != ConnectivityResult.none;

      if (isOnline && photoFile != null) {
        photoUrl =
            await _firestoreService.uploadProducePhoto(photoFile, requestId);
      }

      final request = PickupRequest(
        id: requestId,
        farmerId: cleanFarmerId,
        farmerName: cleanFarmerName,
        farmerPhone: cleanFarmerPhone.isEmpty
            ? null
            : InputValidation.digitsOnly(cleanFarmerPhone),
        aggregatorId: cleanAggregatorId,
        aggregatorName: aggregatorName?.trim().isEmpty == true
            ? null
            : aggregatorName?.trim(),
        collectionPointId: cleanCollectionPointId,
        collectionPointName: cleanCollectionPointName,
        produceType: cleanProduceType,
        quantity: quantity,
        status: RequestStatus.submitted,
        requestedDate: requestedDate,
        photoUrl: photoUrl,
        notes: cleanNotes.isEmpty ? null : cleanNotes,
        isSynced: isOnline,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (isOnline) {
        await _firestoreService.submitRequest(request);
        await _sendRequestSubmittedNotifications(request);
      } else {
        await _localDb.insertOrUpdateRequest(request);
      }

      _requests = [request, ..._requests.where((r) => r.id != request.id)];

      _isLoading = false;
      notifyListeners();
      return true;
    } on ArgumentError catch (e) {
      _error = e.message.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    } on FirebaseException catch (e) {
      _error = e.message ?? 'Failed to submit request. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
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
        await _sendRequestSubmittedNotifications(request);
        await _localDb.markAsSynced(request.id);
      } catch (_) {}
    }
  }

  Future<void> _sendRequestSubmittedNotifications(PickupRequest request) async {
    final aggregatorDisplay =
        (request.aggregatorName?.trim().isNotEmpty ?? false)
            ? request.aggregatorName!.trim()
            : request.aggregatorId;

    final farmerNotification = AppNotification(
      id: '',
      userId: request.farmerId,
      title: 'Pickup Request Submitted',
      message:
          'You have requested a pickup to $aggregatorDisplay for ${request.produceType}.',
      type: NotificationType.general,
      isRead: false,
      requestId: request.id,
      sentAt: DateTime.now(),
    );

    final aggregatorNotification = AppNotification(
      id: '',
      userId: request.aggregatorId,
      title: 'New Pickup Request',
      message: 'You have received a pickup request by ${request.farmerName}.',
      type: NotificationType.general,
      isRead: false,
      requestId: request.id,
      sentAt: DateTime.now(),
    );

    try {
      await _firestoreService.createNotification(farmerNotification);
    } catch (e) {
      debugPrint('Failed to send farmer request-submitted notification: $e');
    }

    try {
      await _firestoreService.createNotification(aggregatorNotification);
    } catch (e) {
      debugPrint(
          'Failed to send aggregator request-submitted notification: $e');
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
      PickupRequest? previousRequest;
      final localIndex = _requests.indexWhere((r) => r.id == requestId);
      if (localIndex != -1) {
        previousRequest = _requests[localIndex];
      } else {
        previousRequest = await _firestoreService.getRequestById(requestId);
      }

      final cleanAdminNotes = InputValidation.normalizeText(adminNotes);
      final cleanAssignedDriverId =
          InputValidation.normalizeText(assignedDriverId);
      final cleanAdminContactPhone = (adminContactPhone ?? '').trim();

      final driverError = InputValidation.driverId(cleanAssignedDriverId);
      if (driverError != null) {
        throw ArgumentError(driverError);
      }
      final phoneError = InputValidation.optionalTenDigitPhone(
        cleanAdminContactPhone,
        fieldName: 'Admin contact phone',
      );
      if (phoneError != null) {
        throw ArgumentError(phoneError);
      }
      final notesError = InputValidation.optionalText(
        cleanAdminNotes,
        fieldName: 'Admin notes',
        maxLength: 1000,
      );
      if (notesError != null) {
        throw ArgumentError(notesError);
      }

      await _firestoreService.updateRequestStatus(
        requestId,
        status,
        adminNotes: cleanAdminNotes.isEmpty ? null : cleanAdminNotes,
        assignedDriverId:
            cleanAssignedDriverId.isEmpty ? null : cleanAssignedDriverId,
        scheduledDate: scheduledDate,
        adminContactPhone:
            cleanAdminContactPhone.isEmpty ? null : cleanAdminContactPhone,
      );

      final index = _requests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        _requests[index] = _requests[index].copyWith(
          status: status,
          adminNotes: cleanAdminNotes.isEmpty ? null : cleanAdminNotes,
          assignedDriverId:
              cleanAssignedDriverId.isEmpty ? null : cleanAssignedDriverId,
          scheduledDate: scheduledDate,
          adminContactPhone:
              cleanAdminContactPhone.isEmpty ? null : cleanAdminContactPhone,
          isSynced: true,
        );
      }

      if (previousRequest != null && previousRequest.status != status) {
        final effectiveScheduledDate =
            scheduledDate ?? previousRequest.scheduledDate;
        await _sendStatusChangeNotifications(
          previousRequest,
          status,
          scheduledDate: effectiveScheduledDate,
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

  Future<void> _sendStatusChangeNotifications(
    PickupRequest request,
    RequestStatus newStatus, {
    DateTime? scheduledDate,
  }) async {
    final aggregatorDisplay =
        (request.aggregatorName?.trim().isNotEmpty ?? false)
            ? request.aggregatorName!.trim()
            : request.aggregatorId;

    final formattedSchedule = scheduledDate == null
        ? null
        : '${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year} ${scheduledDate.hour.toString().padLeft(2, '0')}:${scheduledDate.minute.toString().padLeft(2, '0')}';

    String farmerTitle;
    String farmerMessage;
    String aggregatorTitle;
    String aggregatorMessage;
    NotificationType notificationType;

    switch (newStatus) {
      case RequestStatus.accepted:
        farmerTitle = 'Pickup Accepted';
        farmerMessage =
            'Your ${request.produceType} pickup request has been accepted by $aggregatorDisplay.';
        aggregatorTitle = 'Pickup Accepted';
        aggregatorMessage =
            'You accepted ${request.farmerName}\'s ${request.produceType} pickup request.';
        notificationType = NotificationType.requestAccepted;
      case RequestStatus.scheduled:
        final whenText = formattedSchedule ?? 'soon';
        farmerTitle = 'Pickup Scheduled';
        farmerMessage =
            'Your ${request.produceType} pickup with $aggregatorDisplay is scheduled for $whenText.';
        aggregatorTitle = 'Pickup Scheduled';
        aggregatorMessage =
            'You scheduled ${request.farmerName}\'s ${request.produceType} pickup for $whenText.';
        notificationType = NotificationType.requestScheduled;
      case RequestStatus.pickedUp:
        farmerTitle = 'Pickup Marked Picked Up';
        farmerMessage =
            'Your ${request.produceType} pickup has been marked as picked up by $aggregatorDisplay.';
        aggregatorTitle = 'Pickup Marked Picked Up';
        aggregatorMessage =
            'You marked ${request.farmerName}\'s ${request.produceType} pickup as picked up.';
        notificationType = NotificationType.general;
      case RequestStatus.completed:
        farmerTitle = 'Pickup Completed';
        farmerMessage =
            'Your ${request.produceType} pickup has been completed by $aggregatorDisplay.';
        aggregatorTitle = 'Pickup Completed';
        aggregatorMessage =
            'You marked ${request.farmerName}\'s ${request.produceType} pickup as completed.';
        notificationType = NotificationType.requestCompleted;
      case RequestStatus.cancelled:
        farmerTitle = 'Pickup Cancelled';
        farmerMessage =
            'Your ${request.produceType} pickup request with $aggregatorDisplay has been cancelled.';
        aggregatorTitle = 'Pickup Cancelled';
        aggregatorMessage =
            '${request.farmerName}\'s ${request.produceType} pickup request has been cancelled.';
        notificationType = NotificationType.requestCancelled;
      case RequestStatus.submitted:
        return;
    }

    try {
      await _firestoreService.createNotification(
        AppNotification(
          id: '',
          userId: request.farmerId,
          title: farmerTitle,
          message: farmerMessage,
          type: notificationType,
          isRead: false,
          requestId: request.id,
          sentAt: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('Failed to send farmer status notification: $e');
    }

    try {
      await _firestoreService.createNotification(
        AppNotification(
          id: '',
          userId: request.aggregatorId,
          title: aggregatorTitle,
          message: aggregatorMessage,
          type: notificationType,
          isRead: false,
          requestId: request.id,
          sentAt: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('Failed to send aggregator status notification: $e');
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
