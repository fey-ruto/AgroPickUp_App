import 'package:flutter/material.dart';
import 'dart:async';
import '../models/models.dart';
import '../services/firestore_service.dart';

class NotificationProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription<List<AppNotification>>? _notificationsSubscription;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  void listenToNotifications(String userId) {
    if (userId.trim().isEmpty) {
      clearState();
      return;
    }

    // Cancel previous subscription
    _notificationsSubscription?.cancel();

    // Load initial data and then subscribe for real-time updates
    _firestoreService.getNotifications(userId).then((notifications) {
      _notifications = notifications;
      _unreadCount = notifications.where((n) => !n.isRead).length;
      notifyListeners();

      // Now subscribe to stream for real-time updates
      _notificationsSubscription =
          _firestoreService.notificationsStream(userId).listen(
        (notifications) {
          _notifications = notifications;
          _unreadCount = notifications.where((n) => !n.isRead).length;
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Error loading notifications: $error');
          _notifications = [];
          _unreadCount = 0;
          notifyListeners();
        },
      );
    }).catchError((e) {
      debugPrint('Error loading initial notifications: $e');
      _notifications = [];
      _unreadCount = 0;
      notifyListeners();
    });
  }

  // Force refresh notifications from Firestore
  Future<void> refreshNotifications(String userId) async {
    if (userId.trim().isEmpty) return;
    try {
      final notifications = await _firestoreService.getNotifications(userId);
      _notifications = notifications;
      _unreadCount = notifications.where((n) => !n.isRead).length;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing notifications: $e');
    }
  }

  void clearState() {
    _notificationsSubscription?.cancel();
    _notificationsSubscription = null;
    _notifications = [];
    _unreadCount = 0;
    notifyListeners();
  }

  Future<void> markRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1 && !_notifications[index].isRead) {
      final updated = AppNotification(
        id: _notifications[index].id,
        userId: _notifications[index].userId,
        title: _notifications[index].title,
        message: _notifications[index].message,
        type: _notifications[index].type,
        isRead: true,
        requestId: _notifications[index].requestId,
        sentAt: _notifications[index].sentAt,
      );
      _notifications[index] = updated;
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    }
    await _firestoreService.markNotificationRead(notificationId);
  }

  Future<void> markAllRead(String userId) async {
    final hadUnread = _notifications.any((n) => !n.isRead);
    if (hadUnread) {
      _notifications = _notifications
          .map((n) => AppNotification(
                id: n.id,
                userId: n.userId,
                title: n.title,
                message: n.message,
                type: n.type,
                isRead: true,
                requestId: n.requestId,
                sentAt: n.sentAt,
              ))
          .toList();
      _unreadCount = 0;
      notifyListeners();
    }
    await _firestoreService.markAllNotificationsRead(userId);
  }

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    required NotificationType type,
    String? requestId,
  }) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError('Notification recipient is required.');
    }
    if (title.trim().isEmpty || message.trim().isEmpty) {
      throw ArgumentError('Notification title and message are required.');
    }

    final notification = AppNotification(
      id: '',
      userId: userId.trim(),
      title: title.trim(),
      message: message.trim(),
      type: type,
      isRead: false,
      requestId: requestId,
      sentAt: DateTime.now(),
    );
    await _firestoreService.createNotification(notification);
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    super.dispose();
  }
}
