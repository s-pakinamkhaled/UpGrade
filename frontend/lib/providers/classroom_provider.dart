import 'package:flutter/material.dart';

import '../models/classroom_course.dart';
import '../models/task.dart';
import '../services/classroom_sync_service.dart';
import '../services/classroom_mapper_service.dart';
import '../services/classroom_storage_service.dart';

class ClassroomProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  DateTime? _syncedAt;

  List<ClassroomCourse> _courses = [];
  List<Task> _tasks = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get syncedAt => _syncedAt;
  List<ClassroomCourse> get courses => _courses;
  List<Task> get tasks => _tasks;

  /// Load previously synced data from local storage (so app shows real data on launch).
  Future<void> loadFromStorage() async {
    final courses = await ClassroomStorageService.loadCourses();
    final tasks = await ClassroomStorageService.loadTasks();
    _syncedAt = await ClassroomStorageService.getSyncedAt();
    _courses = courses;
    _tasks = tasks;
    notifyListeners();
  }

  /// Sync with Google Classroom and persist data locally.
  /// Keeps courses and tasks that were added manually (ids starting with `manual_`).
  Future<void> syncClassroom(String accessToken) async {
    _setLoading(true);
    _error = null;

    try {
      final manualCourses =
          _courses.where((c) => c.id.startsWith('manual_')).toList();
      final manualTasks =
          _tasks.where((t) => t.id.startsWith('manual_')).toList();

      final rawData = await ClassroomSyncService.syncAll(accessToken);
      final result = ClassroomMapperService.mapFromRawResponse(rawData);

      _courses = [...manualCourses, ...result.courses];
      _tasks = [...manualTasks, ...result.tasks];
      _syncedAt = DateTime.tryParse(
        rawData['syncedAt'] as String? ?? '',
      ) ?? DateTime.now();

      await ClassroomStorageService.save(
        syncedAt: _syncedAt!.toIso8601String(),
        courses: _courses,
        tasks: _tasks,
      );
    } catch (e) {
      _error = e.toString();
    }

    _setLoading(false);
  }

  void clear() {
    _courses = [];
    _tasks = [];
    _error = null;
    _syncedAt = null;
    ClassroomStorageService.clear();
    notifyListeners();
  }

  /// Add a manual course (not from Classroom sync).
  Future<void> addManualCourse(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final id = 'manual_${DateTime.now().millisecondsSinceEpoch}';
    _courses = [
      ..._courses,
      ClassroomCourse(id: id, name: trimmed),
    ];
    _syncedAt ??= DateTime.now();
    await _saveToStorage();
    notifyListeners();
  }

  /// Remove a manual course and tasks that belong to it.
  Future<void> removeManualCourse(String courseId) async {
    if (!courseId.startsWith('manual_')) return;
    _courses = _courses.where((c) => c.id != courseId).toList();
    _tasks = _tasks.where((t) => t.courseId != courseId).toList();
    await _saveToStorage();
    notifyListeners();
  }

  /// Add a manual task (not from Classroom sync).
  Future<void> addManualTask({
    required String title,
    required DateTime deadline,
    required String courseId,
    required String courseName,
  }) async {
    final id = 'manual_${DateTime.now().millisecondsSinceEpoch}';
    _tasks = [
      ..._tasks,
      Task(
        id: id,
        title: title,
        deadline: deadline,
        courseId: courseId,
        courseName: courseName,
        estimatedMinutes: 60,
        priority: TaskPriority.medium,
        status: TaskStatus.pending,
      ),
    ];
    _syncedAt ??= DateTime.now();
    await _saveToStorage();
    notifyListeners();
  }

  /// Remove a task that was added manually (id starts with `manual_`).
  Future<void> removeManualTask(String taskId) async {
    if (!taskId.startsWith('manual_')) return;
    _tasks = _tasks.where((t) => t.id != taskId).toList();
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    await ClassroomStorageService.save(
      syncedAt: (_syncedAt ?? DateTime.now()).toIso8601String(),
      courses: _courses,
      tasks: _tasks,
    );
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
