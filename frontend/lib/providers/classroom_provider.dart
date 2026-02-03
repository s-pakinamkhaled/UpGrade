import 'package:flutter/material.dart';

import '../models/classroom_course.dart';
import '../models/task.dart';

import '../services/classroom_sync_service.dart';
import '../services/classroom_mapper_service.dart';

class ClassroomProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  List<ClassroomCourse> _courses = [];
  List<Task> _tasks = [];

  // ===== GETTERS =====
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<ClassroomCourse> get courses => _courses;
  List<Task> get tasks => _tasks;

  // ===== MAIN =====
  Future<void> syncClassroom(String accessToken) async {
    _setLoading(true);
    _error = null;

    try {
      // 1️⃣ Fetch classroom raw data
      final rawData =
          await ClassroomSyncService.syncAll(accessToken);

      // 2️⃣ Parse + map
      final result =
          ClassroomMapperService.mapFromRawResponse(rawData);

      _courses = result.courses;
      _tasks = result.tasks;
    } catch (e) {
      _error = e.toString();
    }

    _setLoading(false);
  }

  void clear() {
    _courses = [];
    _tasks = [];
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
