import 'dart:convert';
import 'package:http/http.dart' as http;


/// API Service for connecting to the UpGrade backend
class ApiService {
  // Backend API base URL
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

  // Add more API methods here as needed:
  // - getUserTasks()
  // - createTask()
  // - updateTask()
  // - getStudyPlan()
  // - etc.

}
