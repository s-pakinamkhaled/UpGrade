import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/backend_user_id.dart';
import '../models/classroom_course.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import '../services/classroom_item_classifier_service.dart';
import '../services/classroom_mapper_service.dart';
import '../services/classroom_storage_service.dart';
import '../services/classroom_sync_service.dart';
import '../services/deadline_notification_sync_service.dart';
import '../services/user_matching_profile_sync_service.dart';

class ClassroomProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  DateTime? _syncedAt;
  String? _activeUid;
  bool _googleClassroomConnected = false;

  List<ClassroomCourse> _courses = [];
  List<Task> _tasks = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get syncedAt => _syncedAt;
  String? get activeUid => _activeUid;
  bool get googleClassroomConnected =>
      _googleClassroomConnected || hasGoogleClassroomData(_courses, _tasks);
  List<ClassroomCourse> get courses => _courses;
  List<Task> get tasks => _tasks;
  List<String> get courseIds => _courses.map((c) => c.id).toList();

  static String get _defaultUserId => BackendUserId.resolve();

  /// All synced items. Dashboard screens use this full list.
  List<Task> get allSyncedItems => _tasks;

  /// Real unfinished tasks that are safe to send to AI features.
  List<Task> get actionableTasksForAI => _tasks
      .where((task) => ClassroomItemClassifierService.isActionableForAI(task))
      .toList();

  List<Task> get upcomingActionableTasks => actionableTasksForAI
      .where(
        (task) =>
            (task.status == TaskStatus.pending ||
                task.status == TaskStatus.inProgress) &&
            task.hasUpcomingDeadline,
      )
      .toList();

  List<Task> get gradeItems =>
      _tasks.where((task) => task.isGradeRelated).toList();

  List<Task> get completedItems =>
      _tasks.where((task) => task.status == TaskStatus.completed).toList();

  Map<String, dynamic> get personalizationSignals =>
      ClassroomItemClassifierService.buildPersonalizationSignals(_tasks);

  /// Backward-compatible entry point. Data is now scoped to the active user.
  Future<void> loadFromStorage() => loadForCurrentUser();

  /// Clears in-memory Classroom state when the user signs out or switches accounts.
  Future<void> clearUserData() async {
    _courses = [];
    _tasks = [];
    _error = null;
    _syncedAt = null;
    _isLoading = false;
    _googleClassroomConnected = false;
    _activeUid = null;
    notifyListeners();
  }

  /// Loads Classroom data for the signed-in user only.
  Future<void> loadForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final email = user?.email ?? '(no email)';

    await ClassroomStorageService.clearLegacyGlobalKeys();

    if (uid == null) {
      await clearUserData();
      _logCourseLoad(
        uid: null,
        email: email,
        source: 'signed_out',
        courseCount: 0,
      );
      return;
    }

    if (_activeUid != null && _activeUid != uid) {
      _courses = [];
      _tasks = [];
      _error = null;
      _syncedAt = null;
      _googleClassroomConnected = false;
    }
    _activeUid = uid;

    final cachedCourses = await ClassroomStorageService.loadCourses(uid);
    final cachedTasks = await ClassroomStorageService.loadTasks(uid);
    final cachedSyncedAt = await ClassroomStorageService.getSyncedAt(uid);
    _googleClassroomConnected =
        await ClassroomStorageService.getGoogleClassroomConnected(uid);

    if (cachedCourses.isNotEmpty || cachedTasks.isNotEmpty) {
      _courses = cachedCourses;
      _tasks = ClassroomItemClassifierService.classifyAllIfNeeded(cachedTasks);
      _syncedAt = cachedSyncedAt;
      notifyListeners();
      _logCourseLoad(
        uid: uid,
        email: email,
        source: 'local_cache',
        courseCount: _courses.length,
      );
    } else {
      final fromFirestore = await _loadFromFirestore(uid);
      final hasFirestoreCourses = fromFirestore.courseIds.isNotEmpty ||
          fromFirestore.courses.isNotEmpty;

      if (!hasFirestoreCourses) {
        _courses = [];
        _tasks = [];
        _syncedAt = null;
        notifyListeners();
        _logCourseLoad(
          uid: uid,
          email: email,
          source: 'firestore_empty',
          courseCount: 0,
        );
      } else {
        _courses = fromFirestore.courses;
        _tasks = ClassroomItemClassifierService.classifyAllIfNeeded(
          fromFirestore.tasks,
        );
        _syncedAt = null;
        notifyListeners();
        _logCourseLoad(
          uid: uid,
          email: email,
          source: 'firestore',
          courseCount: _courses.length,
        );
      }
    }

    await UserMatchingProfileSyncService.syncCurrentUserProfile(
      courses: _courses,
      tasks: _tasks,
    );

    await syncTasksToBackend();
    await syncDeadlineNotifications();

    final wasConnected = _googleClassroomConnected;
    await _reconcileGoogleClassroomConnected(uid);
    if (_googleClassroomConnected != wasConnected) {
      notifyListeners();
    }
  }

  /// Creates Firestore deadline notifications for the current user's tasks.
  Future<void> syncDeadlineNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _tasks.isEmpty) return;

    try {
      await DeadlineNotificationSyncService().syncForTasks(
        userId: uid,
        tasks: _tasks,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Classroom] deadline notification sync failed: $e');
      }
    }
  }

  /// True when the user has synced Google Classroom courses or assignments.
  @visibleForTesting
  static bool hasGoogleClassroomData(
    List<ClassroomCourse> courses,
    List<Task> tasks,
  ) {
    if (courses.any((course) => !course.id.startsWith('manual_'))) {
      return true;
    }
    return tasks.any((task) => task.source == 'google_classroom');
  }

  Future<void> _reconcileGoogleClassroomConnected(String uid) async {
    if (_googleClassroomConnected) return;
    if (!hasGoogleClassroomData(_courses, _tasks)) return;
    _googleClassroomConnected = true;
    await ClassroomStorageService.saveGoogleClassroomConnected(uid, true);
  }

  Future<
      ({
        List<ClassroomCourse> courses,
        List<Task> tasks,
        List<String> courseIds,
      })> _loadFromFirestore(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) {
      return (
        courses: <ClassroomCourse>[],
        tasks: <Task>[],
        courseIds: <String>[],
      );
    }

    final data = doc.data() ?? {};
    final rawCourseIds = data['courseIds'];
    final courseIds = rawCourseIds is List
        ? rawCourseIds
            .map((id) => id.toString())
            .where((id) => id.isNotEmpty)
            .toList()
        : <String>[];

    final rawCourses = data['courses'];
    final courses = rawCourses is List
        ? rawCourses
            .whereType<Map>()
            .map((course) => ClassroomCourse.fromJson(
                  Map<String, dynamic>.from(course),
                ))
            .toList()
        : <ClassroomCourse>[];

    if (courseIds.isEmpty && courses.isEmpty) {
      return (
        courses: <ClassroomCourse>[],
        tasks: <Task>[],
        courseIds: <String>[],
      );
    }

    final rawAssignments = data['assignments'];
    final tasks = rawAssignments is List
        ? rawAssignments
            .whereType<Map>()
            .map(_taskFromFirestoreAssignment)
            .whereType<Task>()
            .toList()
        : <Task>[];

    return (courses: courses, tasks: tasks, courseIds: courseIds);
  }

  static Task? _taskFromFirestoreAssignment(Map<dynamic, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    final id = (map['assignmentId'] as String?) ?? (map['id'] as String?) ?? '';
    final title = (map['title'] as String?) ?? '';
    if (id.isEmpty || title.isEmpty) return null;

    return Task(
      id: id,
      title: title,
      deadline:
          DateTime.tryParse(map['deadline'] as String? ?? '') ?? DateTime.now(),
      courseId: (map['courseId'] as String?) ?? '',
      courseName: (map['courseName'] as String?) ?? '',
      priority: TaskPriority.values.firstWhere(
        (priority) => priority.name == (map['priority'] as String?),
        orElse: () => TaskPriority.medium,
      ),
      status: TaskStatus.values.firstWhere(
        (status) => status.name == (map['status'] as String?),
        orElse: () => TaskStatus.pending,
      ),
      estimatedMinutes: 60,
      source: 'google_classroom',
    );
  }

  void _logCourseLoad({
    required String? uid,
    required String email,
    required String source,
    required int courseCount,
  }) {
    if (!kDebugMode) return;
    debugPrint('[Classroom] Current UID: ${uid ?? '(none)'}');
    debugPrint('[Classroom] Current email: $email');
    debugPrint('[Classroom] Course source: $source');
    debugPrint('[Classroom] Course count: $courseCount');
  }

  /// Pushes local tasks to the FastAPI DB for deadline notifications.
  Future<void> syncTasksToBackend() async {
    if (_tasks.isEmpty) return;
    final api = ApiService();
    final userId = _defaultUserId;

    for (final task in _tasks) {
      try {
        await api.upsertTaskForTracking(
          taskId: task.id,
          userId: userId,
          taskJson: task.toJson(),
        );
      } catch (_) {
        // Backend may be offline; notifications degrade gracefully.
      }
    }
  }

  /// Sync with Google Classroom and persist data locally.
  Future<void> syncClassroom(
    String accessToken, {
    String? semesterId,
  }) async {
    final uid = _requireActiveUid();
    _setLoading(true);
    _error = null;

    try {
      final manualCourses =
          _courses.where((course) => course.id.startsWith('manual_')).toList();
      final manualTasks =
          _tasks.where((task) => task.id.startsWith('manual_')).toList();

      final rawData = await ClassroomSyncService.syncAll(
        accessToken,
        semesterId: semesterId,
      );
      final result = ClassroomMapperService.mapFromRawResponse(rawData);
      final previousById = {for (final task in _tasks) task.id: task};
      final mappedTasks = result.tasks
          .map(
            (task) => _applyUserDeadlineOverride(
              task,
              previousById[task.id],
            ),
          )
          .toList();

      _courses = [...manualCourses, ...result.courses];
      _tasks = ClassroomItemClassifierService.classifyAll(
        [...manualTasks, ...mappedTasks],
      );
      _syncedAt = DateTime.tryParse(rawData['syncedAt'] as String? ?? '') ??
          DateTime.now();
      _googleClassroomConnected = true;

      await ClassroomStorageService.save(
        uid: uid,
        syncedAt: _syncedAt!.toIso8601String(),
        courses: _courses,
        tasks: _tasks,
      );
      if (semesterId != null) {
        await ClassroomStorageService.saveSelectedSemesterId(uid, semesterId);
      }
      await ClassroomStorageService.saveGoogleClassroomConnected(uid, true);
      await UserMatchingProfileSyncService.syncCurrentUserProfile(
        courses: _courses,
        tasks: _tasks,
      );
      await syncTasksToBackend();
      await syncDeadlineNotifications();
    } catch (error) {
      _error = error.toString();
    }

    _setLoading(false);
  }

  /// Deprecated compatibility wrapper.
  Future<void> clear() => clearUserData();

  @visibleForTesting
  void seedForTest({
    List<ClassroomCourse> courses = const [],
    List<Task> tasks = const [],
    DateTime? syncedAt,
  }) {
    _courses = List<ClassroomCourse>.from(courses);
    _tasks = ClassroomItemClassifierService.classifyAllIfNeeded(
      List<Task>.from(tasks),
    );
    _syncedAt = syncedAt ?? DateTime.now();
    notifyListeners();
  }

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

  Future<void> removeManualCourse(String courseId) async {
    if (!courseId.startsWith('manual_')) return;

    _courses = _courses.where((course) => course.id != courseId).toList();
    _tasks = _tasks.where((task) => task.courseId != courseId).toList();
    await _saveToStorage();
    await UserMatchingProfileSyncService.syncCurrentUserProfile(
      courses: _courses,
      tasks: _tasks,
    );
    notifyListeners();
  }

  Future<void> addManualTask({
    required String title,
    required DateTime deadline,
    required String courseId,
    required String courseName,
  }) async {
    final id = 'manual_${DateTime.now().millisecondsSinceEpoch}';
    final task = Task(
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
    );

    _tasks = [
      ..._tasks,
      ClassroomItemClassifierService.classifyTask(task),
    ];
    _syncedAt ??= DateTime.now();
    await _saveToStorage();
    await UserMatchingProfileSyncService.syncCurrentUserProfile(
      courses: _courses,
      tasks: _tasks,
    );
    await syncDeadlineNotifications();
    notifyListeners();
  }

  Future<void> removeManualTask(String taskId) async {
    if (!taskId.startsWith('manual_')) return;

    _tasks = _tasks.where((task) => task.id != taskId).toList();
    await _saveToStorage();
    await UserMatchingProfileSyncService.syncCurrentUserProfile(
      courses: _courses,
      tasks: _tasks,
    );
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final uid = _activeUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await ClassroomStorageService.save(
      uid: uid,
      syncedAt: (_syncedAt ?? DateTime.now()).toIso8601String(),
      courses: _courses,
      tasks: _tasks,
    );
  }

  Future<void> updateTaskDeadline(String taskId, DateTime deadline) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);
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

    try {
      await ApiService().upsertTaskForTracking(
        taskId: updated.id,
        userId: _defaultUserId,
        taskJson: updated.toJson(),
      );
    } catch (_) {
      // Backend may be offline; local deadline updates should still succeed.
    }
    await syncDeadlineNotifications();
  }

  /// Updates the student's expected time-to-finish (in minutes) for a task.
  /// Persisted locally and synced so the AI planner uses the customized value.
  Future<void> updateTaskEstimatedMinutes(String taskId, int minutes) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) return;

    final clamped = minutes.clamp(15, 16 * 60);
    final now = DateTime.now();
    final updated = _tasks[index].copyWith(
      estimatedMinutes: clamped,
      updatedAt: now,
    );

    _tasks[index] = updated;
    _syncedAt ??= now;
    await _saveToStorage();
    await UserMatchingProfileSyncService.syncCurrentUserProfile(
      courses: _courses,
      tasks: _tasks,
    );
    notifyListeners();

    try {
      await ApiService().upsertTaskForTracking(
        taskId: updated.id,
        userId: _defaultUserId,
        taskJson: updated.toJson(),
      );
    } catch (_) {
      // Backend may be offline; local estimate updates should still succeed.
    }
  }

  String _requireActiveUid() {
    final uid = _activeUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('Please log in before syncing Classroom data.');
    }
    _activeUid = uid;
    return uid;
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
    final index = _tasks.indexWhere((task) => task.id == taskId);
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
    await syncDeadlineNotifications();
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
