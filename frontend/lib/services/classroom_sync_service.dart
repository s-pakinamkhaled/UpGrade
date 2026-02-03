import 'dart:convert';
import 'package:http/http.dart' as http;

class ClassroomSyncService {
  static const String baseUrl = 'https://classroom.googleapis.com/v1';

  static Future<Map<String, dynamic>> syncAll(String token) async {
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    // 1️⃣ Courses
    final coursesRes = await http.get(
      Uri.parse('$baseUrl/courses'),
      headers: headers,
    );

    final courses = jsonDecode(coursesRes.body)['courses'];

    // 2️⃣ For each course → coursework → submissions
    List<Map<String, dynamic>> allData = [];

    for (final course in courses) {
      final courseId = course['id'];

      final workRes = await http.get(
        Uri.parse('$baseUrl/courses/$courseId/courseWork'),
        headers: headers,
      );

      final works = jsonDecode(workRes.body)['courseWork'] ?? [];

      for (final work in works) {
        final workId = work['id'];

        final subRes = await http.get(
          Uri.parse(
              '$baseUrl/courses/$courseId/courseWork/$workId/studentSubmissions'),
          headers: headers,
        );

        final submissions =
            jsonDecode(subRes.body)['studentSubmissions'] ?? [];

        allData.add({
          'course': course,
          'work': work,
          'submissions': submissions,
        });
      }
    }

    return {
      'syncedAt': DateTime.now().toIso8601String(),
      'data': allData,
    };
  }
}
