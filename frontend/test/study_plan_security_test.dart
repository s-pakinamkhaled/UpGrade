import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/core/security_utils.dart';
import 'package:upgrade/models/study_plan.dart';

void main() {
  group('StudyPlan security / resilience', () {
    test('fromJson handles script-like summary without throwing', () {
      final plan = StudyPlan.fromJson({
        'success': true,
        'studentName': '<img src=x onerror=alert(1)>',
        'generatedAt': '2026-06-12',
        'summary': '<script>alert("xss")</script>',
        'items': [
          {
            'taskTitle': '<b>Normalization</b>',
            'courseName': 'Database',
            'suggestedDate': '2026-06-14',
            'suggestedTime': '10:00',
            'hoursNeeded': 2,
            'priority': 'high',
            'tip': 'Review notes',
          },
        ],
      });

      expect(plan.summary, contains('<script>'));
      expect(plan.items.first.taskTitle, contains('<b>'));
    });

    test('fromJson survives malformed AI response fields', () {
      final plan = StudyPlan.fromJson({
        'items': [
          {
            'taskTitle': null,
            'hoursNeeded': 'not-a-number',
            'priority': null,
          },
        ],
      });

      expect(plan.success, isFalse);
      expect(plan.items.first.taskTitle, isEmpty);
      expect(plan.items.first.hoursNeeded, 1.0);
    });
  });

  group('Pairing session id hardening', () {
    test('accepts normal session ids', () {
      expect(SecurityUtils.isSafePairingSessionId('session_abc123'), isTrue);
      expect(SecurityUtils.isSafePairingSessionId('pair-001'), isTrue);
    });

    test('rejects traversal and special chars', () {
      expect(SecurityUtils.isSafePairingSessionId('../admin'), isFalse);
      expect(SecurityUtils.isSafePairingSessionId('session?id=1'), isFalse);
      expect(SecurityUtils.isSafePairingSessionId('a b'), isFalse);
    });
  });
}
