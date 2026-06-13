import 'package:flutter/material.dart';

import '../models/classroom_course.dart';
import '../models/task.dart';
import '../services/classroom_sync_service.dart';
import '../services/classroom_mapper_service.dart';
import '../services/classroom_storage_service.dart';
import '../services/classroom_item_classifier_service.dart';
import '../services/user_matching_profile_sync_service.dart';
import '../services/api_service.dart';

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

  // ── Filtered views ───────────────────────────────────────────────

  /// All synced items — same as [tasks]. Used by dashboard.
  List<Task> get allSyncedItems => _tasks;

  /// Only real actionable tasks suitable for AI (Study Plan / Chatbot).
  List<Task> get actionableTasksForAI => _tasks
      .where((t) => ClassroomItemClassifierService.isActionableForAI(t))
      .toList();

  /// Actionable tasks that are still pending, missed, or in-progress.
  List<Task> get upcomingActionableTasks => actionableTasksForAI
      .where((t) =>
          t.status == TaskStatus.pending ||
          t.status == TaskStatus.missed ||
          t.status == TaskStatus.inProgress)
      .toList();

  /// Grade-related items only.
  List<Task> get gradeItems => _tasks.where((t) => t.isGradeRelated).toList();

  /// Completed work items.
  List<Task> get completedItems =>
      _tasks.where((t) => t.status == TaskStatus.completed).toList();

  /// Build personalization signals from all data (grades, progress, etc.).
  Map<String, dynamic> get personalizationSignals =>
      ClassroomItemClassifierService.buildPersonalizationSignals(_tasks);

  static const String _defaultUserId = 'student_local';

  /// Load previously synced data from local storage (so app shows real data on launch).
  /// Also pushes [courseIds] / [courses] to Firestore when the user is signed in so
  /// Group Study can match on the same IDs after a relaunch.
  Future<void> loadFromStorage() async {
    final courses = await ClassroomStorageService.loadCourses();
    final tasks = await ClassroomStorageService.loadTasks();
    _syncedAt = await ClassroomStorageService.getSyncedAt();
    _courses = courses;
    _tasks = ClassroomItemClassifierService.classifyAllIfNeeded(tasks);
    notifyListeners();
    await UserMatchingProfileSyncService.syncCurrentUserProfile(
      courses: _courses,
      tasks: _tasks,
    );
  }

  /// Sync with Google Classroom and persist data locally.
  /// Keeps courses and tasks that were added manually (ids starting with `manual_`).
  Future<void> syncClassroom(
    String accessToken, {
    String? semesterId,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final manualCourses =
          _courses.where((c) => c.id.startsWith('manual_')).toList();
      final manualTasks =
          _tasks.where((t) => t.id.startsWith('manual_')).toList();

      final rawData = await ClassroomSyncService.syncAll(
        accessToken,
        semesterId: semesterId,
      );
      final result = ClassroomMapperService.mapFromRawResponse(rawData);
      final previousById = {for (final task in _tasks) task.id: task};
      final mappedTasks = result.tasks
          .map((task) => _applyUserDeadlineOverride(
                task,
                previousById[task.id],
              ))
          .toList();

      _courses = [...manualCourses, ...result.courses];
      _tasks = ClassroomItemClassifierService.classifyAll(
        [...manualTasks, ...mappedTasks],
      );
      _syncedAt = DateTime.tryParse(
            rawData['syncedAt'] as String? ?? '',
          ) ??
          DateTime.now();

      await ClassroomStorageService.save(
        syncedAt: _syncedAt!.toIso8601String(),
        courses: _courses,
        tasks: _tasks,
      );
      if (semesterId != null) {
        await ClassroomStorageService.saveSelectedSemesterId(semesterId);
      }
      await UserMatchingProfileSyncService.syncCurrentUserProfile(
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
    await UserMatchingProfileSyncService.syncCurrentUserProfile(
      courses: _courses,
      tasks: _tasks,
    );
    notifyListeners();
  }

  /// Remove a manual course and tasks that belong to it.
  Future<void> removeManualCourse(String courseId) async {
    if (!courseId.startsWith('manual_')) return;
    _courses = _courses.where((c) => c.id != courseId).toList();
    _tasks = _tasks.where((t) => t.courseId != courseId).toList();
    await _saveToStorage();
    await UserMatchingProfileSyncService.syncCurrentUserProfile(
      courses: _courses,
      tasks: _tasks,
    );
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
      ClassroomItemClassifierService.classifyTask(Task(
        id: id,
        title: title,
        deadline: deadline,
        courseId: courseId,
        courseName: courseName,
        estimatedMinutes: 60,
        priority: TaskPriority.medium,
        status: TaskStatus.pending,
        updatedAt: DateTime.now(),
        source: 'manual',
        hasRealDeadline: true,
        deadlineSource: 'user',
      )),
    ];
    _syncedAt ??= DateTime.now();
    await _saveToStorage();
    await UserMatchingProfileSyncService.syncCurrentUserProfile(
      courses: _courses,
      tasks: _tasks,
    );
    notifyListeners();
  }

  /// Remove a task that was added manually (id starts with `manual_`).
  Future<void> removeManualTask(String taskId) async {
    if (!taskId.startsWith('manual_')) return;
    _tasks = _tasks.where((t) => t.id != taskId).toList();
    await _saveToStorage();
    await UserMatchingProfileSyncService.syncCurrentUserProfile(
      courses: _courses,
      tasks: _tasks,
    );
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    await ClassroomStorageService.save(
      syncedAt: (_syncedAt ?? DateTime.now()).toIso8601String(),
      courses: _courses,
      tasks: _tasks,
    );
  }

  Future<void> updateTaskDeadline(String taskId, DateTime deadline) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return;

    final now = DateTime.now();
    final current = _tasks[index];
    var status = current.status;

    if (status != TaskStatus.completed) {
      if (deadline.isBefore(now)) {
        status = TaskStatus.missed;
      } else if (status == TaskStatus.missed) {
        status = TaskStatus.pending;
      }
    }

    final updated = ClassroomItemClassifierService.classifyTask(
      current.copyWith(
        deadline: deadline,
        status: status,
        updatedAt: now,
        hasRealDeadline: true,
        deadlineSource: 'user',
      ),
    );

    _tasks[index] = updated;
    _syncedAt ??= now;
    await _saveToStorage();
    await UserMatchingProfileSyncService.syncCurrentUserProfile(
      courses: _courses,
      tasks: _tasks,
    );
    notifyListeners();

    ApiService().upsertTaskForTracking(
      taskId: updated.id,
      userId: _defaultUserId,
      taskJson: updated.toJson(),
    );
  }

  Future<void> startTask(String taskId) async {
    await _applyTaskStatus(taskId, TaskStatus.inProgress);
  }

  Future<void> completeTask(String taskId) async {
    await _applyTaskStatus(taskId, TaskStatus.completed);
  }

  Future<void> reopenTask(String taskId) async {
    await _applyTaskStatus(taskId, TaskStatus.pending);
  }

  Future<void> _applyTaskStatus(String taskId, TaskStatus newStatus) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return;

    final current = _tasks[index];
    final now = DateTime.now();

    Task updated = current;
    if (newStatus == TaskStatus.inProgress &&
        current.status == TaskStatus.pending) {
      updated = current.copyWith(
        status: TaskStatus.inProgress,
        startedAt: current.startedAt ?? now,
        updatedAt: now,
      );
    } else if ((current.status == TaskStatus.pending ||
            current.status == TaskStatus.inProgress) &&
        newStatus == TaskStatus.completed) {
      updated = current.copyWith(
        status: TaskStatus.completed,
        completedAt: now,
        updatedAt: now,
      );
    } else if (newStatus == TaskStatus.pending &&
        current.status == TaskStatus.completed) {
      updated = current.copyWith(
        status: TaskStatus.pending,
        clearCompletedAt: true,
        updatedAt: now,
      );
    } else {
      return;
    }

    final api = ApiService();
    await api.upsertTaskForTracking(
      taskId: current.id,
      userId: _defaultUserId,
      taskJson: current.toJson(),
    );
    final serverResponse = await api.updateTaskStatus(
      taskId: current.id,
      status: newStatus.name,
      userId: _defaultUserId,
    );

    if (serverResponse != null &&
        serverResponse['task'] is Map<String, dynamic>) {
      final serverTask =
          Task.fromJson(serverResponse['task'] as Map<String, dynamic>);
      updated = updated.copyWith(
        status: serverTask.status,
        startedAt: serverTask.startedAt ?? updated.startedAt,
        completedAt: serverTask.completedAt,
        clearCompletedAt:
            serverTask.completedAt == null && newStatus == TaskStatus.pending,
        updatedAt: serverTask.updatedAt,
      );
    }

    _tasks[index] = ClassroomItemClassifierService.classifyTask(updated);
    await _saveToStorage();
    notifyListeners();
  }

  Task _applyUserDeadlineOverride(Task mapped, Task? previous) {
    if (previous == null) return mapped;
    if (previous.deadlineSource != 'user') return mapped;
    if (mapped.hasRealDeadline) return mapped;

    final status = mapped.status == TaskStatus.completed
        ? mapped.status
        : previous.deadline.isBefore(DateTime.now())
            ? TaskStatus.missed
            : mapped.status;

    return mapped.copyWith(
      deadline: previous.deadline,
      status: status,
      hasRealDeadline: true,
      deadlineSource: 'user',
    );
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
