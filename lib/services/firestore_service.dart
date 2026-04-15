import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _cloudinaryCloudName = 'dyy3j2gcc';
  static const String _cloudinaryUploadPreset = 'agropick';

  CollectionReference get _users => _db.collection('users');
  CollectionReference get _requests => _db.collection('pickupRequests');
  CollectionReference get _collectionPoints =>
      _db.collection('collectionPoints');
  CollectionReference get _notifications => _db.collection('notifications');

  Future<void> createUser(AppUser user) async {
    await _users.doc(user.id).set(user.toMap());
  }

  Future<AppUser?> getUser(String userId) async {
    final doc = await _users.doc(userId).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc);
  }

  Future<void> updateFcmToken(String userId, String token) async {
    await _users.doc(userId).update({'fcmToken': token});
  }

  Stream<List<PickupRequest>> farmerRequestsStream(String farmerId) {
    return _requests
        .where('farmerId', isEqualTo: farmerId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => PickupRequest.fromFirestore(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<PickupRequest>> allRequestsStream() {
    return _requests.snapshots().map((snap) {
      final list =
          snap.docs.map((d) => PickupRequest.fromFirestore(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<PickupRequest>> aggregatorRequestsStream(String aggregatorId) {
    return _requests
        .where('aggregatorId', isEqualTo: aggregatorId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => PickupRequest.fromFirestore(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<List<PickupRequest>> getFarmerRequests(String farmerId) async {
    if (farmerId.trim().isEmpty) return [];
    final snap = await _requests
        .where('farmerId', isEqualTo: farmerId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => PickupRequest.fromFirestore(d)).toList();
  }

  Future<List<PickupRequest>> getAggregatorRequests(String aggregatorId) async {
    if (aggregatorId.trim().isEmpty) return [];
    final snap = await _requests
        .where('aggregatorId', isEqualTo: aggregatorId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => PickupRequest.fromFirestore(d)).toList();
  }

  Future<String> submitRequest(PickupRequest request) async {
    await _requests.doc(request.id).set(request.toFirestoreMap());
    return request.id;
  }

  Future<PickupRequest?> getRequestById(String requestId) async {
    if (requestId.trim().isEmpty) return null;
    final doc = await _requests.doc(requestId).get();
    if (!doc.exists) return null;
    return PickupRequest.fromFirestore(doc);
  }

  Future<void> updateRequestStatus(
    String requestId,
    RequestStatus status, {
    String? adminNotes,
    String? assignedDriverId,
    DateTime? scheduledDate,
    String? adminContactPhone,
  }) async {
    final Map<String, dynamic> data = {
      'status': status.name,
      'updatedAt': Timestamp.now(),
    };
    if (adminNotes != null) data['adminNotes'] = adminNotes;
    if (assignedDriverId != null) data['assignedDriverId'] = assignedDriverId;
    if (scheduledDate != null)
      data['scheduledDate'] = Timestamp.fromDate(scheduledDate);
    if (adminContactPhone != null)
      data['adminContactPhone'] = adminContactPhone;
    await _requests.doc(requestId).update(data);
  }

  Future<String> uploadProducePhoto(File file, String requestId) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _cloudinaryUploadPreset
      ..fields['public_id'] = 'produce_photos/$requestId'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode < 200 || streamedResponse.statusCode >= 300) {
      throw Exception('Cloudinary upload failed (${streamedResponse.statusCode}): $responseBody');
    }

    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid Cloudinary upload response.');
    }

    final secureUrl = decoded['secure_url'] as String?;
    if (secureUrl == null || secureUrl.trim().isEmpty) {
      throw Exception('No reference to image returned from Cloudinary upload.');
    }

    return secureUrl;
  }

  Stream<List<CollectionPoint>> collectionPointsStream() {
    return _collectionPoints.where('isActive', isEqualTo: true).snapshots().map(
        (snap) =>
            snap.docs.map((d) => CollectionPoint.fromFirestore(d)).toList());
  }

  Future<List<CollectionPoint>> getCollectionPoints() async {
    final snap =
        await _collectionPoints.where('isActive', isEqualTo: true).get();
    return snap.docs.map((d) => CollectionPoint.fromFirestore(d)).toList();
  }

  Future<void> createCollectionPoint(CollectionPoint point) async {
    await _collectionPoints.doc(point.id).set(point.toMap());
  }

  Future<void> updateCollectionPoint(
      String id, Map<String, dynamic> data) async {
    await _collectionPoints.doc(id).update(data);
  }

  Stream<List<AppNotification>> notificationsStream(String userId) {
    if (userId.trim().isEmpty) {
      return const Stream<List<AppNotification>>.empty();
    }
    return _notifications.where('userId', isEqualTo: userId).snapshots().map(
      (snap) {
        final notifications =
            snap.docs.map((d) => AppNotification.fromFirestore(d)).toList();
        notifications.sort((a, b) => b.sentAt.compareTo(a.sentAt));
        return notifications;
      },
    );
  }

  Future<List<AppNotification>> getNotifications(String userId) async {
    if (userId.trim().isEmpty) {
      return [];
    }
    final snap = await _notifications.where('userId', isEqualTo: userId).get();
    final notifications =
        snap.docs.map((d) => AppNotification.fromFirestore(d)).toList();
    notifications.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return notifications;
  }

  Future<void> createNotification(AppNotification notification) async {
    if (notification.userId.trim().isEmpty) {
      throw ArgumentError('Notification recipient is required.');
    }
    if (notification.title.trim().isEmpty ||
        notification.message.trim().isEmpty) {
      throw ArgumentError('Notification title and message are required.');
    }
    await _notifications.add(notification.toMap());
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _notifications.doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllNotificationsRead(String userId) async {
    final snap = await _notifications.where('userId', isEqualTo: userId).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if ((data['isRead'] as bool?) == false) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }

  Future<int> getUnreadNotificationCount(String userId) async {
    final snap = await _notifications.where('userId', isEqualTo: userId).get();
    return snap.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['isRead'] as bool?) == false;
    }).length;
  }
}
