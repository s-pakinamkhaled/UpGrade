import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/classroom_course.dart';
import '../models/task.dart';

/// Persists synced Classroom data locally, scoped per Firebase uid.
class ClassroomStorageService {
  static const String _keySyncedAt = 'classroom_synced_at';
  static const String _keyCourses = 'classroom_courses';
  static const String _keyTasks = 'classroom_tasks';
  static const String _keySelectedSemesterId = 'classroom_selected_semester_id';
  static const String _keyGoogleConnected = 'classroom_google_connected';
  static const String _keyCacheOwnerUid = 'classroom_cache_owner_uid';

  static const List<String> _legacyGlobalKeys = [
    _keySyncedAt,
    _keyCourses,
    _keyTasks,
    _keySelectedSemesterId,
    _keyGoogleConnected,
    _keyCacheOwnerUid,
  ];

  static String _scopedKey(String base, String uid) => '${base}_$uid';

  static Future<void> clearLegacyGlobalKeys() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _legacyGlobalKeys) {
      await prefs.remove(key);
    }
  }

  static Future<void> clearForUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scopedKey(_keySyncedAt, uid));
    await prefs.remove(_scopedKey(_keyCourses, uid));
    await prefs.remove(_scopedKey(_keyTasks, uid));
    await prefs.remove(_scopedKey(_keySelectedSemesterId, uid));
    await prefs.remove(_scopedKey(_keyGoogleConnected, uid));
    final owner = prefs.getString(_keyCacheOwnerUid);
    if (owner == uid) {
      await prefs.remove(_keyCacheOwnerUid);
    }
  }

  static Future<void> save({
    required String uid,
    required String syncedAt,
    required List<ClassroomCourse> courses,
    required List<Task> tasks,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCacheOwnerUid, uid);
    await prefs.setString(_scopedKey(_keySyncedAt, uid), syncedAt);
    await prefs.setString(
      _scopedKey(_keyCourses, uid),
      jsonEncode(courses.map((c) => c.toJson()).toList()),
    );
    await prefs.setString(
      _scopedKey(_keyTasks, uid),
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
  }

  static Future<DateTime?> getSyncedAt(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_scopedKey(_keySyncedAt, uid));
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  static Future<List<ClassroomCourse>> loadCourses(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_scopedKey(_keyCourses, uid));
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

  static Future<List<Task>> loadTasks(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_scopedKey(_keyTasks, uid));
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

  static Future<void> saveSelectedSemesterId(
    String uid,
    String semesterId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCacheOwnerUid, uid);
    await prefs.setString(_scopedKey(_keySelectedSemesterId, uid), semesterId);
  }

  static Future<String?> getSelectedSemesterId(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedKey(_keySelectedSemesterId, uid));
  }

  static Future<void> saveGoogleClassroomConnected(
    String uid,
    bool connected,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCacheOwnerUid, uid);
    await prefs.setBool(_scopedKey(_keyGoogleConnected, uid), connected);
  }

  static Future<bool> getGoogleClassroomConnected(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scopedKey(_keyGoogleConnected, uid)) ?? false;
  }

  /// @deprecated Use [clearForUser] with a uid.
  static Future<void> clear() async {
    await clearLegacyGlobalKeys();
  }
}
