import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/classroom_course.dart';
import '../models/task.dart';
import '../services/classroom_sync_service.dart';
import '../services/classroom_mapper_service.dart';
import '../services/classroom_storage_service.dart';
import '../services/user_matching_profile_sync_service.dart';
import '../services/api_service.dart';
import '../core/backend_user_id.dart';

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
  bool get googleClassroomConnected => _googleClassroomConnected;
  List<ClassroomCourse> get courses => _courses;
  List<Task> get tasks => _tasks;
  List<String> get courseIds => _courses.map((c) => c.id).toList();

  static String get _defaultUserId => BackendUserId.resolve();

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
      _tasks = cachedTasks;
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
        _tasks = fromFirestore.tasks;
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
  }

  /// @deprecated Use [loadForCurrentUser].
  Future<void> loadFromStorage() => loadForCurrentUser();

  Future<({
    List<ClassroomCourse> courses,
    List<Task> tasks,
    List<String> courseIds,
  })> _loadFromFirestore(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) {
      return (courses: <ClassroomCourse>[], tasks: <Task>[], courseIds: <String>[]);
    }

    final data = doc.data() ?? {};
    final rawCourseIds = data['courseIds'];
    final courseIds = rawCourseIds is List
        ? rawCourseIds.map((e) => e.toString()).where((id) => id.isNotEmpty).toList()
        : <String>[];

    final rawCourses = data['courses'];
    final courses = rawCourses is List
        ? rawCourses
            .whereType<Map>()
            .map((c) => ClassroomCourse.fromJson(Map<String, dynamic>.from(c)))
            .toList()
        : <ClassroomCourse>[];

    if (courseIds.isEmpty && courses.isEmpty) {
      return (courses: <ClassroomCourse>[], tasks: <Task>[], courseIds: <String>[]);
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
      deadline: DateTime.tryParse(map['deadline'] as String? ?? '') ??
          DateTime.now(),
      courseId: (map['courseId'] as String?) ?? '',
      courseName: (map['courseName'] as String?) ?? '',
      priority: TaskPriority.values.firstWhere(
        (p) => p.name == (map['priority'] as String?),
        orElse: () => TaskPriority.medium,
      ),
      status: TaskStatus.values.firstWhere(
        (s) => s.name == (map['status'] as String?),
        orElse: () => TaskStatus.pending,
      ),
      estimatedMinutes: 60,
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

  /// Pushes local tasks (with deadlines) to the FastAPI DB for deadline notifications.
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
  /// Keeps courses and tasks that were added manually (ids starting with `manual_`).
  Future<void> syncClassroom(
    String accessToken, {
    String? semesterId,
  }) async {
    final uid = _requireActiveUid();
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

      _courses = [...manualCourses, ...result.courses];
      _tasks = [...manualTasks, ...result.tasks];
      _syncedAt = DateTime.tryParse(
            rawData['syncedAt'] as String? ?? '',
          ) ??
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
    } catch (e) {
      _error = e.toString();
    }

    _setLoading(false);
  }

  /// @deprecated Use [clearUserData].
  Future<void> clear() async {
    await clearUserData();
  }

  /// Seeds in-memory classroom data for integration/widget tests (no storage or Firestore).
  @visibleForTesting
  void seedForTest({
    List<ClassroomCourse> courses = const [],
    List<Task> tasks = const [],
    DateTime? syncedAt,
  }) {
    _courses = List<ClassroomCourse>.from(courses);
    _tasks = List<Task>.from(tasks);
    _syncedAt = syncedAt ?? DateTime.now();
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
      Task(
        id: id,
        title: title,
        deadline: deadline,
        courseId: courseId,
        courseName: courseName,
        estimatedMinutes: 60,
        priority: TaskPriority.medium,
        status: TaskStatus.pending,
        updatedAt: DateTime.now(),
      ),
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
    final uid = _activeUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await ClassroomStorageService.save(
      uid: uid,
      syncedAt: (_syncedAt ?? DateTime.now()).toIso8601String(),
      courses: _courses,
      tasks: _tasks,
    );
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
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return;

    final current = _tasks[index];
    final now = DateTime.now();

    Task updated = current;
    if (newStatus == TaskStatus.inProgress && current.status == TaskStatus.pending) {
      updated = current.copyWith(
        status: TaskStatus.inProgress,
        startedAt: current.startedAt ?? now,
        updatedAt: now,
      );
    } else if ((current.status == TaskStatus.pending || current.status == TaskStatus.inProgress) &&
        newStatus == TaskStatus.completed) {
      updated = current.copyWith(
        status: TaskStatus.completed,
        completedAt: now,
        updatedAt: now,
      );
    } else if (newStatus == TaskStatus.pending && current.status == TaskStatus.completed) {
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

    if (serverResponse != null && serverResponse['task'] is Map<String, dynamic>) {
      final serverTask = Task.fromJson(serverResponse['task'] as Map<String, dynamic>);
      updated = updated.copyWith(
        status: serverTask.status,
        startedAt: serverTask.startedAt ?? updated.startedAt,
        completedAt: serverTask.completedAt,
        clearCompletedAt: serverTask.completedAt == null && newStatus == TaskStatus.pending,
        updatedAt: serverTask.updatedAt,
      );
    }

    _tasks[index] = updated;
    await _saveToStorage();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
