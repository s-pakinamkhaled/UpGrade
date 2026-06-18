import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/task.dart';

class DeadlineSyncResult {
  final int createdCount;
  final int skippedCount;
  final int scannedTaskCount;

  const DeadlineSyncResult({
    required this.createdCount,
    required this.skippedCount,
    required this.scannedTaskCount,
  });
}

class _ReminderSpec {
  final String id;
  final String title;
  final String message;
  final String type;
  final String taskId;
  final DateTime deadline;

  const _ReminderSpec({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.taskId,
    required this.deadline,
  });
}

/// Creates deadline reminder docs at users/{userId}/notifications/{notificationId}.
class DeadlineNotificationSyncService {
  DeadlineNotificationSyncService._({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static final DeadlineNotificationSyncService _instance =
      DeadlineNotificationSyncService._();
  factory DeadlineNotificationSyncService() => _instance;

  final FirebaseFirestore _db;

  static const _upcomingTitle = 'Upcoming Deadline';
  static const _missedSummaryId = 'missed_tasks_summary';
  static const _missedSummaryTitle = 'Oops, you missed some tasks';
  static const _missedSummaryType = 'missed_summary';
  static const _manualTestTitle = 'Firebase notification test';

  static final RegExp _legacyStagedDocId = RegExp(
    r'^deadline_.+_(3d|24h|6h|overdue)$',
  );

  CollectionReference<Map<String, dynamic>> _notificationsRef(String userId) {
    return _db.collection('users').doc(userId).collection('notifications');
  }

  /// One deterministic notification document per task.
  static String deadlineDocId(String taskId) {
    return 'deadline_${_safeTaskId(taskId)}';
  }

  static String _safeTaskId(String taskId) {
    return taskId.replaceAll('/', '_');
  }

  Future<DeadlineSyncResult> syncForTasks({
    required String userId,
    required List<Task> tasks,
  }) async {
    if (userId.isEmpty) {
      return const DeadlineSyncResult(
        createdCount: 0,
        skippedCount: 0,
        scannedTaskCount: 0,
      );
    }

    final now = DateTime.now();
    var createdCount = 0;
    var skippedCount = 0;
    final col = _notificationsRef(userId);

    await _purgeLegacyNotifications(col);

    for (final task in tasks) {
      final ref = col.doc(deadlineDocId(task.id));

      if (task.status == TaskStatus.completed || !task.hasRealDeadline) {
        if (await _deleteIfExists(ref)) skippedCount++;
        continue;
      }

      if (_isMissedTask(task, now)) {
        if (await _deleteIfExists(ref)) skippedCount++;
        continue;
      }

      final reminder = _activeReminderForTask(task, now);
      if (reminder == null) {
        if (await _deleteIfExists(ref)) skippedCount++;
        continue;
      }

      final existing = await ref.get();
      if (!existing.exists) {
        await ref.set(_newReminderPayload(reminder));
        createdCount++;
        continue;
      }

      final data = existing.data() ?? {};
      final sameType = data['type'] == reminder.type;
      final sameMessage = data['message'] == reminder.message;
      if (sameType && sameMessage) {
        skippedCount++;
        continue;
      }

      await ref.update(_stageUpdatePayload(reminder));
      skippedCount++;
    }

    await _syncMissedTasksSummary(
      col: col,
      tasks: tasks,
      now: now,
      onCreated: () => createdCount++,
      onUpdated: () => skippedCount++,
      onDeleted: () {},
    );

    if (kDebugMode) {
      debugPrint(
        '[DeadlineNotification] userId=$userId scanned=${tasks.length} '
        'created=$createdCount skipped=$skippedCount',
      );
    }

    return DeadlineSyncResult(
      createdCount: createdCount,
      skippedCount: skippedCount,
      scannedTaskCount: tasks.length,
    );
  }

  Map<String, dynamic> _newReminderPayload(_ReminderSpec reminder) {
    return {
      'title': reminder.title,
      'message': reminder.message,
      'type': reminder.type,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'taskId': reminder.taskId,
      'deadline': Timestamp.fromDate(reminder.deadline),
    };
  }

  Map<String, dynamic> _stageUpdatePayload(_ReminderSpec reminder) {
    return {
      'title': reminder.title,
      'message': reminder.message,
      'type': reminder.type,
      'taskId': reminder.taskId,
      'deadline': Timestamp.fromDate(reminder.deadline),
    };
  }

  Future<bool> _deleteIfExists(DocumentReference<Map<String, dynamic>> ref) async {
    final snap = await ref.get();
    if (!snap.exists) return false;
    await ref.delete();
    return true;
  }

  Future<void> _purgeLegacyNotifications(
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    final allSnap = await col.get();
    if (allSnap.docs.isEmpty) return;

    final batch = _db.batch();
    var deleteCount = 0;

    for (final doc in allSnap.docs) {
      final data = doc.data();
      final title = data['title'] as String?;
      final type = data['type'] as String?;
      final shouldDelete = title == _manualTestTitle ||
          type == 'deadline_overdue' ||
          _legacyStagedDocId.hasMatch(doc.id);
      if (!shouldDelete) continue;
      batch.delete(doc.reference);
      deleteCount++;
    }

    if (deleteCount == 0) return;
    await batch.commit();

    if (kDebugMode) {
      debugPrint(
        '[DeadlineNotification] removed $deleteCount legacy/test notifications',
      );
    }
  }

  Future<void> _syncMissedTasksSummary({
    required CollectionReference<Map<String, dynamic>> col,
    required List<Task> tasks,
    required DateTime now,
    required VoidCallback onCreated,
    required VoidCallback onUpdated,
    required VoidCallback onDeleted,
  }) async {
    final missedCount = _countMissedTasks(tasks, now);
    final ref = col.doc(_missedSummaryId);

    if (missedCount == 0) {
      if (await _deleteIfExists(ref)) onDeleted();
      return;
    }

    final message =
        'You missed $missedCount task${missedCount == 1 ? '' : 's'}. Review them to stay on track.';
    final existing = await ref.get();

    if (!existing.exists) {
      await ref.set({
        'title': _missedSummaryTitle,
        'message': message,
        'type': _missedSummaryType,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'missedCount': missedCount,
      });
      onCreated();
      return;
    }

    final data = existing.data() ?? {};
    final previousCount = (data['missedCount'] as num?)?.toInt();
    final previousMessage = data['message'] as String?;

    if (previousCount == missedCount && previousMessage == message) {
      onUpdated();
      return;
    }

    await ref.update({
      'title': _missedSummaryTitle,
      'message': message,
      'missedCount': missedCount,
    });
    onUpdated();
  }

  static int _countMissedTasks(List<Task> tasks, DateTime now) {
    return tasks.where((task) => _isMissedTask(task, now)).length;
  }

  static bool _isMissedTask(Task task, DateTime now) {
    if (task.status == TaskStatus.completed) return false;
    if (!task.hasRealDeadline) return false;
    if (task.status == TaskStatus.missed) return true;
    return task.deadline.toLocal().isBefore(now);
  }

  /// Returns the single highest-priority upcoming stage, or null if none apply.
  static _ReminderSpec? _activeReminderForTask(Task task, DateTime now) {
    final title =
        task.title.trim().isEmpty ? 'Untitled task' : task.title.trim();
    final deadline = task.deadline.toLocal();
    final timeUntil = deadline.difference(now);

    if (timeUntil.inSeconds <= 0) return null;

    if (timeUntil <= const Duration(hours: 6)) {
      return _ReminderSpec(
        id: deadlineDocId(task.id),
        title: _upcomingTitle,
        message: '$title is due in 6 hours.',
        type: 'deadline_6h',
        taskId: task.id,
        deadline: deadline,
      );
    }

    if (timeUntil <= const Duration(hours: 24)) {
      return _ReminderSpec(
        id: deadlineDocId(task.id),
        title: _upcomingTitle,
        message: '$title is due in 24 hours.',
        type: 'deadline_24h',
        taskId: task.id,
        deadline: deadline,
      );
    }

    if (timeUntil <= const Duration(days: 3)) {
      return _ReminderSpec(
        id: deadlineDocId(task.id),
        title: _upcomingTitle,
        message: '$title is due in 3 days.',
        type: 'deadline_3d',
        taskId: task.id,
        deadline: deadline,
      );
    }

    return null;
  }
}
