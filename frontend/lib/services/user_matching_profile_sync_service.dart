import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/classroom_course.dart';
import '../models/task.dart';
import 'classroom_storage_service.dart';

class UserMatchingProfileSyncService {
  static const String _defaultAvailableStart = '18:00';
  static const String _defaultAvailableEnd = '21:00';

  static Future<void> syncCurrentUserProfile({
    List<ClassroomCourse>? courses,
    List<Task>? tasks,
    String? nameOverride,
    String? emailOverride,
    FirebaseFirestore? firestore,
    User? authUser,
    bool resolveAuthFromFirebase = true,
  }) async {
    final user = authUser ??
        (resolveAuthFromFirebase ? FirebaseAuth.instance.currentUser : null);
    if (user == null) return;

    final resolvedCourses = courses ??
        await ClassroomStorageService.loadCourses(user.uid);
    final resolvedTasks =
        tasks ?? await ClassroomStorageService.loadTasks(user.uid);
    final prefs = await SharedPreferences.getInstance();

    final availableStart =
        prefs.getString('profile_available_start') ?? _defaultAvailableStart;
    final availableEnd =
        prefs.getString('profile_available_end') ?? _defaultAvailableEnd;
    final studyGoals = _deriveStudyGoalsFromPrefs(prefs);
    final workloadScore = _calculateWorkloadScore(resolvedTasks);
    final riskLevel = _calculateRiskLevel(
      tasks: resolvedTasks,
      workloadScore: workloadScore,
    );

    final assignments = resolvedTasks
        .map(
          (t) => {
            'assignmentId': t.id,
            'title': t.title,
            'courseId': t.courseId,
            'courseName': t.courseName,
            'deadline': t.deadline.toIso8601String(),
            'status': t.status.name,
            'priority': t.priority.name,
          },
        )
        .toList();

    final courseIds = resolvedCourses.map((c) => c.id).toSet().toList();
    final coursesPayload = resolvedCourses
        .map((c) => <String, dynamic>{'id': c.id, 'name': c.name})
        .toList();
    final now = DateTime.now();
    final availableStartIso = _toTodayIso(now, availableStart);
    final availableEndIso = _toTodayIso(now, availableEnd);

    if (kDebugMode) {
      debugPrint(
        '[ProfileSync] users/${user.uid} courseIds (${courseIds.length}): $courseIds',
      );
    }

    await (firestore ?? FirebaseFirestore.instance)
        .collection('users')
        .doc(user.uid)
        .set({
      'uid': user.uid,
      'name': nameOverride ?? user.displayName ?? 'Student',
      'email': emailOverride ?? user.email ?? '',
      'courseIds': courseIds,
      'courses': coursesPayload,
      'assignments': assignments,
      'availableStart': availableStartIso,
      'availableEnd': availableEndIso,
      'studyGoals': studyGoals,
      'workloadScore': workloadScore,
      'riskLevel': riskLevel,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static List<String> _deriveStudyGoalsFromPrefs(SharedPreferences prefs) {
    final style = prefs.getString('settings_study_style') ?? 'visual';
    final difficulty = prefs.getString('settings_difficulty') ?? 'balanced';
    final goals = <String>{'general study session'};

    if (style == 'practice') {
      goals.add('assignment solving');
      goals.add('quiz revision');
    } else if (style == 'reading') {
      goals.add('exam preparation');
    } else {
      goals.add('quiz revision');
    }

    if (difficulty == 'challenging') {
      goals.add('exam preparation');
    } else if (difficulty == 'easy') {
      goals.add('general study session');
    }

    return goals.toList();
  }

  static int _calculateWorkloadScore(List<Task> tasks) {
    if (tasks.isEmpty) return 0;
    final now = DateTime.now();
    var score = 0.0;

    for (final task in tasks) {
      if (task.status == TaskStatus.completed) continue;
      final base = (task.estimatedMinutes / 30).clamp(1, 12).toDouble();
      var priorityMultiplier = 1.0;
      switch (task.priority) {
        case TaskPriority.low:
          priorityMultiplier = 0.8;
          break;
        case TaskPriority.medium:
          priorityMultiplier = 1.0;
          break;
        case TaskPriority.high:
          priorityMultiplier = 1.3;
          break;
        case TaskPriority.urgent:
          priorityMultiplier = 1.6;
          break;
      }

      final daysLeft =
          task.hasRealDeadline ? task.deadline.difference(now).inDays : null;
      final deadlineBoost = daysLeft == null
          ? 1.0
          : daysLeft < 0
              ? 2.0
              : daysLeft <= 1
                  ? 1.8
                  : daysLeft <= 3
                      ? 1.4
                      : 1.0;
      score += base * priorityMultiplier * deadlineBoost;
    }

    // Normalize into 0..100.
    final normalized = (score * 2).clamp(0, 100);
    return normalized.round();
  }

  static String _calculateRiskLevel({
    required List<Task> tasks,
    required int workloadScore,
  }) {
    final overdue = tasks
        .where(
          (t) =>
              t.status != TaskStatus.completed &&
              t.hasRealDeadline &&
              t.deadline.isBefore(DateTime.now()),
        )
        .length;
    if (workloadScore >= 75 || overdue >= 3) return 'high';
    if (workloadScore >= 40 || overdue >= 1) return 'medium';
    return 'low';
  }

  static String _toTodayIso(DateTime now, String hhmm) {
    final parts = hhmm.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 18 : 18;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final dt = DateTime(now.year, now.month, now.day, hour, minute);
    return dt.toIso8601String();
  }
}
