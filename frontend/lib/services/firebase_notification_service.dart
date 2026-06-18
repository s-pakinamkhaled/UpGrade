import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';

class NotificationListResult {
  final List<AppNotification> items;
  final int unreadCount;

  const NotificationListResult({
    required this.items,
    required this.unreadCount,
  });
}

/// In-app notifications stored at users/{userId}/notifications/{notificationId}.
class FirebaseNotificationService {
  FirebaseNotificationService._({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static final FirebaseNotificationService _instance =
      FirebaseNotificationService._();
  factory FirebaseNotificationService() => _instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _notificationsRef(String userId) {
    return _db.collection('users').doc(userId).collection('notifications');
  }

  /// Real-time notifications ordered by newest first.
  Stream<NotificationListResult> notificationsStream(String userId) {
    return _notificationsRef(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_snapshotToResult);
  }

  NotificationListResult _snapshotToResult(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final userId = snapshot.docs.isNotEmpty
        ? snapshot.docs.first.reference.parent.parent?.id ?? ''
        : '';
    final items = snapshot.docs
        .map((doc) => AppNotification.fromFirestore(
              doc,
              userId: doc.reference.parent.parent?.id ?? userId,
            ))
        .toList();
    final listItems = items.where((n) => n.isListItem).toList();
    final unreadCount = listItems.where((n) => !n.isRead).length;
    if (kDebugMode) {
      debugPrint(
        '[FirebaseNotification] stream total=${items.length} '
        'list=${listItems.length} unread=$unreadCount',
      );
    }
    return NotificationListResult(items: items, unreadCount: unreadCount);
  }

  Future<void> purgeManualTestNotifications(String userId) async {
    final snap = await _notificationsRef(userId)
        .where('title', isEqualTo: AppNotification.manualTestTitle)
        .get();
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    if (kDebugMode) {
      debugPrint(
        '[FirebaseNotification] removed ${snap.docs.length} manual test notifications',
      );
    }
  }

  Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    await _notificationsRef(userId).doc(notificationId).update({
      'isRead': true,
    });
  }

  Future<void> markAllAsRead(String userId) async {
    final unreadSnap = await _notificationsRef(userId)
        .where('isRead', isEqualTo: false)
        .get();
    if (unreadSnap.docs.isEmpty) return;

    final batch = _db.batch();
    var updated = 0;
    for (final doc in unreadSnap.docs) {
      final data = doc.data();
      if (data['type'] == 'missed_summary') continue;
      if (data['title'] == AppNotification.manualTestTitle) continue;
      batch.update(doc.reference, {'isRead': true});
      updated++;
    }
    if (updated == 0) return;
    await batch.commit();
  }
}
