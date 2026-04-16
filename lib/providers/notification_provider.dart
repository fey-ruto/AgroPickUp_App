import 'package:flutter/material.dart';
import 'dart:async';
import '../models/models.dart';
import '../services/firestore_service.dart';

class NotificationProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription<List<AppNotification>>? _notificationsSubscription;
  String? _listeningUserId;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  void listenToNotifications(String userId) {
    if (_listeningUserId == userId && _notificationsSubscription != null) {
      return;
    }

    _notificationsSubscription?.cancel();
    _listeningUserId = userId;

    _notificationsSubscription =
        _firestoreService.notificationsStream(userId).listen((notifications) {
      _notifications = notifications;
      _unreadCount = notifications.where((n) => !n.isRead).length;
      notifyListeners();
    });
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
    final notification = AppNotification(
      id: '',
      userId: userId,
      title: title,
      message: message,
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
