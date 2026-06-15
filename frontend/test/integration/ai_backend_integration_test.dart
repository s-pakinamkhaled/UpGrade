import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:upgrade/models/study_plan.dart';
import 'package:upgrade/models/task.dart';
import 'package:upgrade/services/api_service.dart';

import '../helpers/task_fixtures.dart';

/// Simulates a minimal backend that implements the AI routes the Flutter app calls.
MockClient createMockAiBackend() {
  return MockClient((request) async {
    final path = request.url.path;

    if (path == '/api/plan/health' && request.method == 'GET') {
      return http.Response(
        json.encode({'status': 'ok', 'service': 'llama-3.3-70b-versatile'}),
        200,
      );
    }

    if (path == '/api/chat/health' && request.method == 'GET') {
      return http.Response(
        json.encode({'status': 'ok', 'provider': 'groq'}),
        200,
      );
    }

    if (path == '/api/plan/generate' && request.method == 'POST') {
      final body = json.decode(request.body) as Map<String, dynamic>;
      final tasks = (body['tasks'] as List).cast<Map<String, dynamic>>();
      final realTasks = tasks
          .where((t) => !(t['title'] as String? ?? '').toLowerCase().contains('grade'))
          .where((t) => (t['status'] as String? ?? '') != 'completed')
          .toList();

      if (realTasks.isEmpty) {
        return http.Response(json.encode({'detail': 'No active tasks'}), 400);
      }

      final top = realTasks.first;
      return http.Response(
        json.encode({
          'success': true,
          'studentName': body['studentName'],
          'generatedAt': '2026-06-12T10:00:00',
          'summary': 'Focus on ${top['title']} first.',
          'items': [
            {
              'taskTitle': top['title'],
              'courseName': top['courseName'] ?? '',
              'suggestedDate': '2026-06-14',
              'suggestedTime': '14:00 - 16:00',
              'hoursNeeded': 2,
              'priority': top['priority'] ?? 'medium',
              'tip': 'Block two focused hours for this task.',
            },
          ],
        }),
        200,
      );
    }

    if (path == '/api/chat/message' && request.method == 'POST') {
      final body = json.decode(request.body) as Map<String, dynamic>;
      final ctx = body['student_context'] as Map<String, dynamic>?;
      final tasks = (ctx?['tasks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final name = ctx?['name'] ?? 'Student';

      final reply = tasks.isEmpty
          ? 'Hi $name! Sync your tasks so I can help.'
          : 'Hi $name! Start with ${tasks.first['title']}.';

      return http.Response(
        json.encode({
          'success': true,
          'message': reply,
          'model': 'llama-3.3-70b-versatile',
          'suggestions': ['What should I study now?', 'Suggest a study schedule'],
        }),
        200,
      );
    }

    if (path == '/api/chat/suggestions') {
      return http.Response(
        json.encode({'suggestions': ['What should I study now?']}),
        200,
      );
    }

    return http.Response('not found', 404);
  });
}

Map<String, dynamic> buildStudentContext({
  required String name,
  required List<Task> tasks,
}) {
  return {
    'name': name,
    'tasks': tasks
        .map(
          (task) => {
            'title': task.title,
            'courseName': task.courseName,
            'priority': task.priority.name,
            'status': task.status.name,
            'deadline': task.deadline.toIso8601String(),
            'estimatedMinutes': task.estimatedMinutes,
          },
        )
        .toList(),
  };
}

void main() {
  const base = 'http://ai-integration-test';

  setUp(() {
    ApiService.testBaseUrl = base;
    ApiService.testHttpClient = createMockAiBackend();
  });

  tearDown(ApiService.resetTestOverrides);

  group('Frontend ↔ backend AI integration (mock server)', () {
    test('classroom tasks → study plan → StudyPlan model', () async {
      final tasks = [
        makeTask(
          id: 'hw_1',
          title: 'Database Normalization HW',
          courseName: 'Database Systems',
          status: TaskStatus.pending,
          priority: TaskPriority.high,
        ),
        makeTask(
          id: 'grade_1',
          title: 'Quiz 2 grades',
          status: TaskStatus.pending,
        ),
        makeTask(
          id: 'done_1',
          title: 'Old Essay',
          status: TaskStatus.completed,
        ),
      ];

      final activeTasks = tasks
          .where(
            (t) =>
                t.status == TaskStatus.pending ||
                t.status == TaskStatus.inProgress,
          )
          .toList();

      final raw = await ApiService().generateStudyPlan(
        studentName: 'Pakinam',
        tasks: activeTasks,
      );

      expect(raw, isNotNull);
      final plan = StudyPlan.fromJson(raw!);
      expect(plan.success, isTrue);
      expect(plan.items.first.taskTitle, 'Database Normalization HW');
      expect(plan.summary, contains('Database Normalization HW'));
    });

    test('student context → chat message → AI reply with suggestions', () async {
      final tasks = [
        makeTask(
          title: 'Graph Algorithms Lab',
          courseName: 'Algorithms',
          priority: TaskPriority.urgent,
        ),
      ];

      final response = await ApiService().sendChatMessage(
        message: 'What should I study now?',
        studentContext: buildStudentContext(name: 'Pakinam', tasks: tasks),
      );

      expect(response!['success'], isTrue);
      expect(response['message'], contains('Graph Algorithms Lab'));
      expect(response['suggestions'], isA<List>());
    });

    test('full AI journey: plan then follow-up chat', () async {
      final task = makeTask(
        title: 'Machine Learning Project',
        courseName: 'AI',
        status: TaskStatus.pending,
      );

      final planRaw = await ApiService().generateStudyPlan(
        studentName: 'Pakinam',
        tasks: [task],
      );
      final plan = StudyPlan.fromJson(planRaw!);
      final topTask = plan.items.first.taskTitle;

      final chat = await ApiService().sendChatMessage(
        message: 'Why should I start with $topTask?',
        studentContext: buildStudentContext(name: 'Pakinam', tasks: [task]),
      );

      expect(chat!['success'], isTrue);
      expect(chat['message'], isNotEmpty);
    });

    test('chat suggestions endpoint returns prompts', () async {
      final suggestions = await ApiService().getChatSuggestions(
        hasUrgentTasks: true,
      );

      expect(suggestions, isNotEmpty);
    });
  });
}
