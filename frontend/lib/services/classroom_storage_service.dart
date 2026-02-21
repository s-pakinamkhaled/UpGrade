import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/classroom_course.dart';
import '../models/task.dart';

/// Persists synced Classroom data locally so the app uses real data after sync.
const String _keySyncedAt = 'classroom_synced_at';
const String _keyCourses = 'classroom_courses';
const String _keyTasks = 'classroom_tasks';

class ClassroomStorageService {
  static Future<void> save({
    required String syncedAt,
    required List<ClassroomCourse> courses,
    required List<Task> tasks,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySyncedAt, syncedAt);
    await prefs.setString(
      _keyCourses,
      jsonEncode(courses.map((c) => c.toJson()).toList()),
    );
    await prefs.setString(
      _keyTasks,
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
  }

  static Future<DateTime?> getSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keySyncedAt);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  static Future<List<ClassroomCourse>> loadCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keyCourses);
    if (s == null) return [];
    try {
      final list = jsonDecode(s) as List<dynamic>;
      return list
          .map((e) => ClassroomCourse.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Task>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keyTasks);
    if (s == null) return [];
    try {
      final list = jsonDecode(s) as List<dynamic>;
      return list
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySyncedAt);
    await prefs.remove(_keyCourses);
    await prefs.remove(_keyTasks);
  }
}
