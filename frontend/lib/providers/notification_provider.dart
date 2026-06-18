import 'package:flutter/foundation.dart';

import '../core/backend_user_id.dart';
import '../models/app_notification.dart';
import '../services/notification_api_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationApiService _api = NotificationApiService();

  List<AppNotification> _items = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  static String resolveUserId() => BackendUserId.resolve();

  Future<void> refreshUnreadCount([String? userId]) async {
    final id = userId ?? resolveUserId();
    try {
      final result = await _api.fetchUnreadNotifications(id);
      _unreadCount = result.unreadCount;
      _error = null;
    } catch (e) {
      debugPrint('Failed to refresh unread count: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> refresh([String? userId]) async {
    final id = userId ?? resolveUserId();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _api.fetchNotifications(id);
      _items = result.items;
      _unreadCount = result.unreadCount;
    } catch (e) {
      _error = e.toString();
      debugPrint('Failed to refresh notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId, [String? userId]) async {
    final id = userId ?? resolveUserId();
    final updated = await _api.markAsRead(
      userId: id,
      notificationId: notificationId,
    );
    if (updated == null) return;

    _items = _items
        .map((n) => n.id == notificationId ? updated : n)
        .toList(growable: false);
    _unreadCount = _items.where((n) => !n.isRead).length;
    notifyListeners();
  }

  Future<void> markAllAsRead([String? userId]) async {
    final id = userId ?? resolveUserId();
    final updatedCount = await _api.markAllAsRead(id);
    if (updatedCount == null) return;

    _items = _items.map((n) => n.copyWith(isRead: true)).toList(growable: false);
    _unreadCount = 0;
    notifyListeners();
  }

  void resetForNewSession() {
    _items = [];
    _unreadCount = 0;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
