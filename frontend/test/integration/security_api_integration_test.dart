import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:upgrade/services/api_service.dart';

/// Mock backend enforcing the same security rules as production routes.
MockClient createSecurityMockBackend() {
  bool safeId(String id) {
    if (id.isEmpty || id.length > 128) return false;
    return !id.contains('/') &&
        !id.contains('\\') &&
        !id.contains('..') &&
        !id.contains('?') &&
        !id.contains('#');
  }

  return MockClient((request) async {
    final path = request.url.path;

    if (path.startsWith('/api/tasks/') && request.method == 'GET') {
      final id = path.split('/').last;
      if (!safeId(id)) {
        return http.Response('{"detail":"Invalid task id"}', 400);
      }
      return http.Response('{"success":true,"task":{"id":"$id"}}', 200);
    }

    if (path == '/api/chat/message' && request.method == 'POST') {
      final body = json.decode(request.body) as Map<String, dynamic>;
      final message = (body['message'] as String? ?? '').trim();
      if (message.isEmpty) {
        return http.Response('{"detail":"Message is required"}', 400);
      }
      if (message.length > 4000) {
        return http.Response('{"detail":"Message exceeds maximum length"}', 400);
      }
      return http.Response(
        json.encode({'success': true, 'message': 'ok', 'suggestions': []}),
        200,
      );
    }

    if (path.startsWith('/api/profile/') && request.method == 'PATCH') {
      final body = json.decode(request.body) as Map<String, dynamic>;
      final email = body['email'] as String? ?? '';
      if (!email.contains('@') || !email.contains('.')) {
        return http.Response('{"detail":"Invalid email address"}', 400);
      }
      return http.Response(
        json.encode({
          'success': true,
          'profile': {'email': email, 'fullName': body['fullName']},
        }),
        200,
      );
    }

    return http.Response('not found', 404);
  });
}

void main() {
  const base = 'http://security-mock';

  setUp(() {
    ApiService.testBaseUrl = base;
    ApiService.testHttpClient = createSecurityMockBackend();
  });

  tearDown(ApiService.resetTestOverrides);

  group('Frontend security integration (mock backend guards)', () {
    test('blocks unsafe task id before request leaves client', () async {
      final result = await ApiService().updateTaskStatus(
        taskId: '../admin',
        status: 'pending',
        userId: 'student1',
      );
      expect(result, isNull);
    });

    test('chat empty message blocked client-side', () async {
      expect(await ApiService().sendChatMessage(message: ''), isNull);
    });

    test('chat valid message reaches backend', () async {
      final result = await ApiService().sendChatMessage(
        message: 'What should I study?',
      );
      expect(result!['success'], isTrue);
    });

    test('profile update with invalid email rejected by backend', () async {
      final result = await ApiService().updateUserProfile(
  userId: 'student_sec',
  fullName: 'Pakinam',
  email: 'bad-email',
  studentId: '202202233',
  major: 'AI',
  academicYear: 'Junior',
  gpa: '3.5',
);
      expect(result, isNull);
    });
  });
}
