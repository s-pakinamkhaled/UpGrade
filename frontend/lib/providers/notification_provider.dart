import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../services/firebase_notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final FirebaseNotificationService _service = FirebaseNotificationService();

  List<AppNotification> _items = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<NotificationListResult>? _subscription;
  String? _listeningUserId;

  /// All Firestore notification docs (including missed summary).
  List<AppNotification> get items => List.unmodifiable(_items);

  /// Deadline/upcoming notifications only (excludes missed summary + manual test).
  List<AppNotification> get listItems =>
      _items.where((notification) => notification.isListItem).toList(growable: false);

  AppNotification? get missedSummaryNotification {
    for (final notification in _items) {
      if (notification.isMissedSummary) return notification;
    }
    return null;
  }

  int get missedCount => missedSummaryNotification?.missedCount ?? 0;

  int get totalCount => listItems.length;

  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  static String? resolveUserId() => FirebaseAuth.instance.currentUser?.uid;

  void startListening([String? userId]) {
    final id = userId ?? resolveUserId();
    if (id == null || id.isEmpty) {
      resetForNewSession();
      return;
    }

    if (_listeningUserId == id && _subscription != null) {
      return;
    }

    _subscription?.cancel();
    _listeningUserId = id;
    _isLoading = true;
    _error = null;
    notifyListeners();

    unawaited(_service.purgeManualTestNotifications(id));

    _subscription = _service.notificationsStream(id).listen(
      (result) {
        _items = result.items;
        _unreadCount = result.unreadCount;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _error = e.toString();
        _isLoading = false;
        debugPrint('Failed to listen to notifications: $e');
        notifyListeners();
      },
    );
  }

  Future<void> refreshUnreadCount([String? userId]) async {
    startListening(userId);
  }

  Future<void> refresh([String? userId]) async {
    final id = userId ?? resolveUserId();
    if (id == null || id.isEmpty) {
      resetForNewSession();
      return;
    }

    await _service.purgeManualTestNotifications(id);

    if (_listeningUserId != id) {
      startListening(id);
      return;
    }

    _subscription?.cancel();
    _subscription = null;
    _listeningUserId = null;
    startListening(id);
  }

  Future<void> markAsRead(String notificationId, [String? userId]) async {
    final id = userId ?? resolveUserId();
    if (id == null) return;

    try {
      await _service.markAsRead(userId: id, notificationId: notificationId);
    } catch (e) {
      debugPrint('Failed to mark notification read: $e');
    }
  }

  Future<void> markAllAsRead([String? userId]) async {
    final id = userId ?? resolveUserId();
    if (id == null) return;

    try {
      await _service.markAllAsRead(id);
    } catch (e) {
      debugPrint('Failed to mark all notifications read: $e');
    }
  }

  void resetForNewSession() {
    _subscription?.cancel();
    _subscription = null;
    _listeningUserId = null;
    _items = [];
    _unreadCount = 0;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
