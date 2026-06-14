import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_notification.dart';
import 'api_service.dart';

class NotificationListResult {
  final List<AppNotification> items;
  final int unreadCount;

  const NotificationListResult({
    required this.items,
    required this.unreadCount,
  });
}

class NotificationApiService {
  static final NotificationApiService _instance =
      NotificationApiService._internal();
  factory NotificationApiService() => _instance;
  NotificationApiService._internal();

  static const Duration _timeout = Duration(seconds: 10);

  Future<NotificationListResult> fetchNotifications(String userId) async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/notifications')
        .replace(queryParameters: {'userId': userId});
    final response = await http
        .get(uri, headers: {'Content-Type': 'application/json'})
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load notifications (${response.statusCode})',
      );
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final items = (body['items'] as List<dynamic>? ?? [])
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
    return NotificationListResult(
      items: items,
      unreadCount: (body['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<NotificationListResult> fetchUnreadNotifications(String userId) async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/notifications/unread')
        .replace(queryParameters: {'userId': userId});
    final response = await http
        .get(uri, headers: {'Content-Type': 'application/json'})
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load unread notifications (${response.statusCode})',
      );
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final items = (body['items'] as List<dynamic>? ?? [])
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
    return NotificationListResult(
      items: items,
      unreadCount: (body['unreadCount'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<AppNotification?> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    final uri =
        Uri.parse('${ApiService.baseUrl}/api/notifications/$notificationId/read')
            .replace(queryParameters: {'userId': userId});
    final response = await http
        .patch(uri, headers: {'Content-Type': 'application/json'})
        .timeout(_timeout);

    if (response.statusCode != 200) {
      debugPrint(
        'Mark read API error: ${response.statusCode} ${response.body}',
      );
      return null;
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final notification = body['notification'] as Map<String, dynamic>?;
    if (notification == null) return null;
    return AppNotification.fromJson(notification);
  }

  Future<int?> markAllAsRead(String userId) async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/notifications/read-all')
        .replace(queryParameters: {'userId': userId});
    final response = await http
        .patch(uri, headers: {'Content-Type': 'application/json'})
        .timeout(_timeout);

    if (response.statusCode != 200) {
      debugPrint(
        'Mark all read API error: ${response.statusCode} ${response.body}',
      );
      return null;
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    return (body['updatedCount'] as num?)?.toInt();
  }
}
