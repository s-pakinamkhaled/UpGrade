import 'dart:convert';
import 'package:http/http.dart' as http;


/// API Service for connecting to the UpGrade backend
class ApiService {
  // Backend API base URL — must match backend port (run: run-backend.ps1 or uvicorn on 8001)
  // Web/desktop: 127.0.0.1:8001. Android emulator: 10.0.2.2:8001
  static const String baseUrl = 'http://127.0.0.1:8001';
  
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Check backend health
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Health check failed: $e');
      return false;
    }
  }

  /// Get welcome message from backend
  Future<Map<String, dynamic>?> getWelcomeMessage() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Failed to get welcome message: $e');
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
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/chat/message'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': message,
          'conversation_history': conversationHistory,
          'student_context': studentContext,
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      print('Chat API error: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Failed to send chat message: $e');
      return null;
    }
  }

  /// Get quick suggestions for chat
  Future<List<String>> getChatSuggestions({
    bool hasUrgentTasks = false,
    bool hasUpcomingDeadline = false,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/suggestions?has_urgent_tasks=$hasUrgentTasks&has_upcoming_deadline=$hasUpcomingDeadline'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['suggestions'] ?? []);
      }
      return [];
    } catch (e) {
      print('Failed to get suggestions: $e');
      return [];
    }
  }

  /// Generate a personalised study plan from the student's active tasks.
  Future<Map<String, dynamic>?> generateStudyPlan({
    required String studentName,
    required List tasks,
  }) async {
    try {
      final taskPayload = tasks.map((t) {
        final json = t.toJson();
        return {
          'id': json['id'] ?? '',
          'title': json['title'] ?? '',
          'courseName': json['courseName'] ?? '',
          'deadline': json['deadline'],
          'estimatedMinutes': json['estimatedMinutes'] ?? 60,
          'priority': json['priority'] ?? 'medium',
          'status': json['status'] ?? 'pending',
          'description': json['description'],
          'assignedGrade': json['assignedGrade'],
          'maxPoints': json['maxPoints'],
        };
      }).toList();

      final response = await http.post(
        Uri.parse('$baseUrl/api/plan/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'studentName': studentName,
          'tasks': taskPayload,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      print('Plan API error: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      print('Failed to generate study plan: $e');
      return null;
    }
  }

  Future<bool> upsertTaskForTracking({
    required String taskId,
    required String userId,
    required Map<String, dynamic> taskJson,
  }) async {
    try {
      final payload = {
        'id': taskId,
        'userId': userId,
        'title': taskJson['title'],
        'status': taskJson['status'] ?? 'pending',
        'startedAt': taskJson['startedAt'],
        'completedAt': taskJson['completedAt'],
        'updatedAt': taskJson['updatedAt'] ?? DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/tasks'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Failed to upsert task for tracking: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> updateTaskStatus({
    required String taskId,
    required String status,
    required String userId,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/tasks/$taskId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': status, 'userId': userId}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }

      print('Task status API error: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      print('Failed to update task status: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/profile/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        return body['profile'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Failed to fetch user profile: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateUserProfile({
    required String userId,
    required String fullName,
    required String email,
    required String major,
    required String academicYear,
    required String gpa,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/profile/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fullName': fullName,
          'email': email,
          'major': major,
          'academicYear': academicYear,
          'gpa': gpa,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        return body['profile'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Failed to update user profile: $e');
      return null;
    }
  }

  // Add more API methods here as needed:
  // - getUserTasks()
  // - createTask()
  // - updateTask()
  // - etc.

}
