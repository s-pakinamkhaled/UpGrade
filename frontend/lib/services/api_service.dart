import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/security_utils.dart';

/// API Service for connecting to the UpGrade backend
class ApiService {
  // Backend API base URL — must match backend port (run: run-backend.ps1 or uvicorn on 8001)
  // Web/desktop: 127.0.0.1:8001. Android emulator: 10.0.2.2:8001
  static const String baseUrl = 'https://upgrade-backend-v1op.onrender.com';

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Overrides for unit/integration tests (mock HTTP client + base URL).
  @visibleForTesting
  static http.Client? testHttpClient;

  @visibleForTesting
  static String? testBaseUrl;

  @visibleForTesting
  static void resetTestOverrides() {
    testHttpClient = null;
    testBaseUrl = null;
  }

  String get _apiBase => testBaseUrl ?? baseUrl;
  http.Client get _http => testHttpClient ?? http.Client();

  /// Check backend health
  Future<bool> checkHealth() async {
    try {
      final response = await _http.get(
        Uri.parse('$_apiBase/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Health check failed: $e');
      return false;
    }
  }

  /// Get welcome message from backend
  Future<Map<String, dynamic>?> getWelcomeMessage() async {
    try {
      final response = await _http.get(
        Uri.parse('$_apiBase/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Failed to get welcome message: $e');
      return null;
    }
  }

  /// Test backend connection
  Future<String> testConnection() async {
    final isHealthy = await checkHealth();
    if (isHealthy) {
      final message = await getWelcomeMessage();
      return message?['message'] ?? 'Backend is running';
    }
    return 'Backend connection failed';
  }

  /// Send a message to the AI chatbot
  Future<Map<String, dynamic>?> sendChatMessage({
    required String message,
    List<Map<String, String>>? conversationHistory,
    Map<String, dynamic>? studentContext,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || trimmed.length > 4000) {
      debugPrint('Blocked unsafe chat message length or content');
      return null;
    }
    try {
      final response = await _http
          .post(
            Uri.parse('$_apiBase/api/chat/message'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'message': trimmed,
              'conversation_history': conversationHistory,
              'student_context': studentContext,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      debugPrint('Chat API error: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Failed to send chat message: $e');
      return null;
    }
  }

  /// Get quick suggestions for chat
  Future<List<String>> getChatSuggestions({
    bool hasUrgentTasks = false,
    bool hasUpcomingDeadline = false,
  }) async {
    try {
      final response = await _http.get(
        Uri.parse(
            '$_apiBase/api/chat/suggestions?has_urgent_tasks=$hasUrgentTasks&has_upcoming_deadline=$hasUpcomingDeadline'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['suggestions'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Failed to get suggestions: $e');
      return [];
    }
  }

  /// Generate a personalised study plan from the student's active tasks.
  ///
  /// [defaultDailyHours] is how many hours/day the student wants to study by
  /// default; [dailyHours] holds per-date overrides (date 'yyyy-MM-dd' → hours)
  /// so the plan can be tailored to each day's availability.
  Future<Map<String, dynamic>?> generateStudyPlan({
    required String studentName,
    required List tasks,
    double? defaultDailyHours,
    Map<String, double>? dailyHours,
  }) async {
    try {
      final taskPayload = tasks.map((t) {
        final json = t.toJson();
        final hasRealDeadline = json['hasRealDeadline'] as bool? ?? true;
        return {
          'id': json['id'] ?? '',
          'title': json['title'] ?? '',
          'courseName': json['courseName'] ?? '',
          'deadline': hasRealDeadline ? json['deadline'] : null,
          'estimatedMinutes': json['estimatedMinutes'] ?? 60,
          'priority': json['priority'] ?? 'medium',
          'status': json['status'] ?? 'pending',
          'description': json['description'],
          'assignedGrade': json['assignedGrade'],
          'maxPoints': json['maxPoints'],
          // Classification metadata for backend safety validation
          'source': json['source'] ?? 'unknown',
          'itemType': json['itemType'] ?? 'unknown',
          'isActionableForAI': json['isActionableForAI'] ?? true,
          'isGradeRelated': json['isGradeRelated'] ?? false,
          'isDashboardOnly': json['isDashboardOnly'] ?? false,
          'classificationConfidence': json['classificationConfidence'],
          'classificationReason': json['classificationReason'],
          'classroomWorkType': json['classroomWorkType'],
          'classroomSubmissionState': json['classroomSubmissionState'],
          'classroomLate': json['classroomLate'],
          'hasRealDeadline': hasRealDeadline,
          'deadlineSource': json['deadlineSource'],
        };
      }).toList();

      final dailyHoursPayload = (dailyHours ?? {})
          .entries
          .map((e) => {'date': e.key, 'hours': e.value})
          .toList();

      final response = await _http
          .post(
            Uri.parse('$_apiBase/api/plan/generate'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'studentName': studentName,
              'tasks': taskPayload,
              if (defaultDailyHours != null)
                'defaultDailyHours': defaultDailyHours,
              if (dailyHoursPayload.isNotEmpty) 'dailyHours': dailyHoursPayload,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      debugPrint('Plan API error: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Failed to generate study plan: $e');
      return null;
    }
  }

  Future<bool> upsertTaskForTracking({
    required String taskId,
    required String userId,
    required Map<String, dynamic> taskJson,
  }) async {
    if (!SecurityUtils.isSafePathSegment(taskId) ||
        !SecurityUtils.isSafePathSegment(userId)) {
      debugPrint('Blocked unsafe task tracking ids');
      return false;
    }
    try {
      final payload = {
        'id': taskId,
        'userId': userId,
        'title': taskJson['title'],
        'status': taskJson['status'] ?? 'pending',
        'deadline': taskJson['deadline'],
        'startedAt': taskJson['startedAt'],
        'completedAt': taskJson['completedAt'],
        'updatedAt': taskJson['updatedAt'] ?? DateTime.now().toIso8601String(),
      };

      final response = await _http
          .post(
            Uri.parse('$_apiBase/api/tasks'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Failed to upsert task for tracking: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> updateTaskStatus({
    required String taskId,
    required String status,
    required String userId,
  }) async {
    if (!SecurityUtils.isSafePathSegment(taskId) ||
        !SecurityUtils.isSafePathSegment(userId)) {
      debugPrint('Blocked unsafe task status ids');
      return null;
    }
    try {
      final response = await _http
          .patch(
            Uri.parse('$_apiBase/api/tasks/$taskId/status'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'status': status, 'userId': userId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }

      debugPrint(
          'Task status API error: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Failed to update task status: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    if (!SecurityUtils.isSafePathSegment(userId)) {
      debugPrint('Blocked unsafe profile userId');
      return null;
    }
    try {
      final response = await _http.get(
        Uri.parse('$_apiBase/api/profile/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        return body['profile'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Failed to fetch user profile: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateUserProfile({
    required String userId,
    required String fullName,
    required String email,
    required String studentId,
    required String major,
    required String academicYear,
    required String gpa,
  }) async {
    if (!SecurityUtils.isSafePathSegment(userId)) {
      debugPrint('Blocked unsafe profile userId');
      return null;
    }
    try {
      final response = await _http
          .patch(
            Uri.parse('$_apiBase/api/profile/$userId'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'fullName': SecurityUtils.sanitizeDisplayInput(fullName),
              'email': email.trim(),
              'studentId': studentId,
              'major': SecurityUtils.sanitizeDisplayInput(major),
              'academicYear': SecurityUtils.sanitizeDisplayInput(academicYear),
              'gpa': SecurityUtils.sanitizeDisplayInput(gpa, maxLength: 16),     
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        return body['profile'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Failed to update user profile: $e');
      return null;
    }
  }

  /// Send course room invitation emails via backend SMTP service.
  Future<void> sendCourseRoomInviteEmails({
    required List<String> recipientEmails,
    required String courseName,
    required String inviterName,
  }) async {
    final validEmails = SecurityUtils.filterInviteRecipientEmails(recipientEmails);
    if (validEmails.isEmpty) return;

    final response = await _http
        .post(
          Uri.parse('$_apiBase/api/notifications/course-room-invite'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'recipientEmails': validEmails,
            'courseName': SecurityUtils.sanitizeDisplayInput(courseName),
            'inviterName': SecurityUtils.sanitizeDisplayInput(inviterName),
            'appUrl': 'http://localhost:5750/#/home',
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      debugPrint(
          'Invite email API error: ${response.statusCode} ${response.body}');
      throw Exception('Failed to send invite emails.');
    }
  }

  // Add more API methods here as needed:
  // - getUserTasks()
  // - createTask()
  // - updateTask()
  // - etc.
}
