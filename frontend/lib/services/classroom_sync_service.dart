import 'dart:convert';
import 'package:http/http.dart' as http;

class ClassroomSyncService {
  static const String baseUrl = 'https://classroom.googleapis.com/v1';

  /// Set to true to print sync debug info in the console (run with flutter run).
  static bool debug = true;

  /// Fetches all courses, course work (assignments), and student submissions.
  /// Returns data grouped by course: each item has { course, works, submissions }
  /// so the mapper can build tasks with names, deadlines, and grades.
  static Future<Map<String, dynamic>> syncAll(String token) async {
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    // 1) List courses (student courses)
    final coursesUrl = '$baseUrl/courses?studentId=me';
    if (debug) print('[ClassroomSync] GET $coursesUrl');
    final coursesRes = await http.get(
      Uri.parse(coursesUrl),
      headers: headers,
    );

    if (coursesRes.statusCode != 200) {
      if (debug) print('[ClassroomSync] courses error: ${coursesRes.statusCode} ${coursesRes.body}');
      throw Exception('Failed to load courses: ${coursesRes.body}');
    }

    final body = jsonDecode(coursesRes.body);
    final coursesList = body['courses'] as List<dynamic>? ?? [];
    if (debug) print('[ClassroomSync] courses count: ${coursesList.length}');

    final List<Map<String, dynamic>> allData = [];

    for (final c in coursesList) {
      final course = Map<String, dynamic>.from(c as Map);
      final courseId = course['id'] as String? ?? '';
      final courseName = course['name'] as String? ?? '';

      // 2) Course work (assignments) for this course – no filter so we get all types
      final workUrl = '$baseUrl/courses/$courseId/courseWork';
      if (debug) print('[ClassroomSync] GET courseWork for $courseName ($courseId)');
      final workRes = await http.get(
        Uri.parse(workUrl),
        headers: headers,
      );

      if (workRes.statusCode != 200 && debug) {
        print('[ClassroomSync] courseWork error: ${workRes.statusCode} ${workRes.body}');
      }

      final workList = workRes.statusCode == 200
          ? (jsonDecode(workRes.body)['courseWork'] as List<dynamic>?) ?? []
          : <dynamic>[];

      if (debug) print('[ClassroomSync]   courseWork count: ${workList.length}');

      final List<Map<String, dynamic>> works = [];
      final List<Map<String, dynamic>> allSubmissions = [];

      for (final w in workList) {
        final work = Map<String, dynamic>.from(w as Map);
        work['courseId'] = courseId;
        final workId = work['id'] as String? ?? '';
        final title = work['title'] as String? ?? '';
        final due = work['dueDate'];
        if (debug) print('[ClassroomSync]     work: "$title" dueDate=$due');

        final subRes = await http.get(
          Uri.parse(
            '$baseUrl/courses/$courseId/courseWork/$workId/studentSubmissions',
          ),
          headers: headers,
        );

        final subList = subRes.statusCode == 200
            ? (jsonDecode(subRes.body)['studentSubmissions'] as List<dynamic>?) ?? []
            : <dynamic>[];

        for (final s in subList) {
          final sub = Map<String, dynamic>.from(s as Map);
          sub['courseWorkId'] = workId;
          sub['courseId'] = courseId;
          allSubmissions.add(sub);
        }
        works.add(work);
      }

      allData.add({
        'course': course,
        'works': works,
        'submissions': allSubmissions,
      });
    }

    if (debug) {
      final totalWorks = allData.fold<int>(0, (n, e) => n + (e['works'] as List).length);
      print('[ClassroomSync] done: ${coursesList.length} courses, $totalWorks courseWork items');
    }

    return {
      'syncedAt': DateTime.now().toIso8601String(),
      'data': allData,
    };
  }
}
