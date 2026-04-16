import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/models.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _cloudinaryUploadUrl =
      'https://api.cloudinary.com/v1_1/agropickup/image/upload';
  static const _cloudinaryUploadPreset = 'dyd6layw2';

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

  Future<String> submitRequest(PickupRequest request) async {
    await _requests.doc(request.id).set(request.toFirestoreMap());
    return request.id;
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
    if (scheduledDate != null) {
      data['scheduledDate'] = Timestamp.fromDate(scheduledDate);
    }
    if (adminContactPhone != null) {
      data['adminContactPhone'] = adminContactPhone;
    }
    await _requests.doc(requestId).update(data);
  }

  Future<String> uploadProducePhoto(File file, String requestId) async {
    if (!file.existsSync()) {
      throw Exception('Photo file not found at path: ${file.path}');
    }

    // Read file bytes with a timeout so a stuck file read can't hang forever.
    final bytes = await file.readAsBytes().timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException('Reading photo file timed out'),
    );
    debugPrint('[Cloudinary] Read ${bytes.length} bytes — $requestId');

    // Build multipart request using in-memory bytes (no lazy stream).
    final uri = Uri.parse(_cloudinaryUploadUrl);
    final multipartFile =
        http.MultipartFile.fromBytes('file', bytes, filename: '$requestId.jpg');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _cloudinaryUploadPreset
      ..files.add(multipartFile);

    // Use IOClient with a TCP-level connectionTimeout so a stalled socket
    // cannot block the Dart event loop beyond the specified duration.
    final nativeClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    final client = IOClient(nativeClient);

    debugPrint('[Cloudinary] Sending upload request…');
    try {
      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 15));

      debugPrint('[Cloudinary] Status: ${response.statusCode}');
      debugPrint('[Cloudinary] Body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
            'Cloudinary upload failed (${response.statusCode}): ${response.body}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final secureUrl = json['secure_url'] as String;
      debugPrint('[Cloudinary] Success: $secureUrl');
      return secureUrl;
    } finally {
      client.close();
    }
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
    return _notifications
        .where('userId', isEqualTo: userId)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AppNotification.fromFirestore(d)).toList());
  }

  Future<void> createNotification(AppNotification notification) async {
    await _notifications.add(notification.toMap());
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _notifications.doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllNotificationsRead(String userId) async {
    final snap = await _notifications
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<int> getUnreadNotificationCount(String userId) async {
    final snap = await _notifications
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    return snap.size;
  }
}
