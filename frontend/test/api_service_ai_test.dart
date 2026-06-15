import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:upgrade/models/study_plan.dart';
import 'package:upgrade/models/task.dart';
import 'package:upgrade/services/api_service.dart';

import 'helpers/task_fixtures.dart';

void main() {
  const testBase = 'http://mock-backend';

  setUp(() {
    ApiService.testBaseUrl = testBase;
  });

  tearDown(() {
    ApiService.resetTestOverrides();
  });

  group('ApiService AI endpoints (mock backend)', () {
    test('sendChatMessage posts student context and parses AI reply', () async {
      ApiService.testHttpClient = MockClient((request) async {
        expect(request.url.path, '/api/chat/message');
        expect(request.method, 'POST');

        final body = json.decode(request.body) as Map<String, dynamic>;
        expect(body['message'], 'What should I study now?');
        expect(body['student_context']['name'], 'Pakinam');
        expect(body['student_context']['tasks'], isA<List>());

        return http.Response(
          json.encode({
            'success': true,
            'message': 'Start with Database Normalization HW.',
            'model': 'llama-3.3-70b-versatile',
            'suggestions': ['Help me prioritize my tasks'],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final response = await ApiService().sendChatMessage(
        message: 'What should I study now?',
        conversationHistory: [
          {'role': 'assistant', 'content': 'Hi Pakinam!'},
        ],
        studentContext: {
          'name': 'Pakinam',
          'tasks': [
            {
              'title': 'Database Normalization HW',
              'priority': 'high',
              'status': 'pending',
            },
          ],
        },
      );

      expect(response, isNotNull);
      expect(response!['success'], isTrue);
      expect(response['message'], contains('Normalization'));
      expect(response['suggestions'], isA<List>());
    });

    test('getChatSuggestions returns backend suggestion list', () async {
      ApiService.testHttpClient = MockClient((request) async {
        expect(request.url.path, '/api/chat/suggestions');
        expect(request.url.query, contains('has_urgent_tasks=true'));

        return http.Response(
          json.encode({
            'suggestions': [
              'What urgent tasks should I do first?',
              'Suggest a study schedule',
            ],
          }),
          200,
        );
      });

      final suggestions = await ApiService().getChatSuggestions(
        hasUrgentTasks: true,
        hasUpcomingDeadline: false,
      );

      expect(suggestions, hasLength(2));
      expect(suggestions.first, contains('urgent'));
    });

    test('generateStudyPlan sends task payload and parses plan response', () async {
      final task = makeTask(
        id: 'task_1',
        title: 'AI Assignment',
        status: TaskStatus.pending,
        courseName: 'Artificial Intelligence',
      );

      ApiService.testHttpClient = MockClient((request) async {
        expect(request.url.path, '/api/plan/generate');

        final body = json.decode(request.body) as Map<String, dynamic>;
        expect(body['studentName'], 'Pakinam');
        final tasks = body['tasks'] as List;
        expect(tasks, hasLength(1));
        expect(tasks.first['title'], 'AI Assignment');
        expect(tasks.first['courseName'], 'Artificial Intelligence');

        return http.Response(
          json.encode({
            'success': true,
            'studentName': 'Pakinam',
            'generatedAt': '2026-06-12T12:00:00',
            'summary': 'Focus on the AI assignment.',
            'items': [
              {
                'taskTitle': 'AI Assignment',
                'courseName': 'Artificial Intelligence',
                'suggestedDate': '2026-06-14',
                'suggestedTime': '10:00 - 12:00',
                'hoursNeeded': 2,
                'priority': 'high',
                'tip': 'Review lecture notes.',
              },
            ],
          }),
          200,
        );
      });

      final raw = await ApiService().generateStudyPlan(
        studentName: 'Pakinam',
        tasks: [task],
      );

      expect(raw, isNotNull);
      final plan = StudyPlan.fromJson(raw!);
      expect(plan.success, isTrue);
      expect(plan.items.first.taskTitle, 'AI Assignment');
    });

    test('returns null when AI backend responds with error status', () async {
      ApiService.testHttpClient = MockClient((request) async {
        return http.Response('{"detail":"Planner unavailable"}', 503);
      });

      final result = await ApiService().generateStudyPlan(
        studentName: 'Pakinam',
        tasks: [makeTask()],
      );

      expect(result, isNull);
    });
  });
}
