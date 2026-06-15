import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:upgrade/core/constants.dart';
import 'package:upgrade/services/api_service.dart';
import 'package:upgrade/services/google_auth_service.dart';

void main() {
  tearDown(ApiService.resetTestOverrides);

  group('ApiService security guards', () {
    test('blocks unsafe userId in profile fetch', () async {
      final result = await ApiService().getUserProfile('../admin');
      expect(result, isNull);
    });

    test('blocks unsafe taskId in status update', () async {
      final result = await ApiService().updateTaskStatus(
        taskId: '../../tasks',
        status: 'pending',
        userId: 'student1',
      );
      expect(result, isNull);
    });

    test('blocks unsafe ids in task upsert', () async {
      final ok = await ApiService().upsertTaskForTracking(
        taskId: 'task?x=1',
        userId: 'student1',
        taskJson: {'title': 'Test'},
      );
      expect(ok, isFalse);
    });

    test('blocks empty chat message before HTTP', () async {
      final result = await ApiService().sendChatMessage(message: '   ');
      expect(result, isNull);
    });

    test('blocks oversized chat message before HTTP', () async {
      final result = await ApiService().sendChatMessage(
        message: 'A' * 5000,
      );
      expect(result, isNull);
    });

    test('sanitizes invite payload fields', () async {
      ApiService.testHttpClient = MockClient((request) async {
        final body = json.decode(request.body) as Map<String, dynamic>;
        expect(body['courseName'], 'Database Systems');
        expect(body['inviterName'], 'Pakinam');
        expect(body['recipientEmails'], ['peer@test.com']);
        return http.Response('{"sent":0,"failed":[],"total":1}', 200);
      });
      ApiService.testBaseUrl = 'http://mock';

      await ApiService().sendCourseRoomInviteEmails(
        recipientEmails: ['peer@test.com', 'invalid', ''],
        courseName: '  Database   Systems  ',
        inviterName: '  Pakinam  ',
      );
    });
  });

  group('Google Classroom OAuth scopes', () {
    test('uses read-only classroom scopes only', () {
      final scopes = GoogleAuthService.instance.scopes;

      expect(scopes, isNotEmpty);
      for (final scope in scopes) {
        expect(scope, contains('googleapis.com/auth/classroom'));
        expect(scope.toLowerCase(), isNot(contains('write')));
        expect(scope.toLowerCase(), isNot(contains('modify')));
      }
    });
  });

  group('App security constants', () {
    test('privacy and pairing pages use https hosting', () {
      expect(
        AppConstants.publicPrivacyPolicyPageUrl.startsWith('https://'),
        isTrue,
      );
      expect(
        AppConstants.pairingQrLandingPageUrl.startsWith('https://'),
        isTrue,
      );
    });

    test('sensitive routes are not main shell tabs', () {
      expect(AppConstants.routeLogin, isNot('/home'));
      expect(AppConstants.routeEndSession, '/end-session');
    });
  });
}
