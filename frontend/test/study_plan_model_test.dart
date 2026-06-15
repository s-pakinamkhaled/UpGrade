import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/models/study_plan.dart';

void main() {
  group('StudyPlanItem.fromJson', () {
    test('parses full AI plan item', () {
      final item = StudyPlanItem.fromJson({
        'taskTitle': 'Database HW',
        'courseName': 'Database Systems',
        'suggestedDate': '2026-06-15',
        'suggestedTime': '14:00 – 16:00',
        'hoursNeeded': 2.5,
        'priority': 'high',
        'tip': 'Review normalization examples first.',
      });

      expect(item.taskTitle, 'Database HW');
      expect(item.courseName, 'Database Systems');
      expect(item.hoursNeeded, 2.5);
      expect(item.priority, 'high');
      expect(item.tip, contains('normalization'));
    });

    test('defaults missing fields safely', () {
      final item = StudyPlanItem.fromJson({});

      expect(item.taskTitle, isEmpty);
      expect(item.hoursNeeded, 1.0);
      expect(item.priority, 'medium');
    });
  });

  group('StudyPlan.fromJson', () {
    test('parses backend AI planner response', () {
      final plan = StudyPlan.fromJson({
        'success': true,
        'studentName': 'Pakinam',
        'generatedAt': '2026-06-12T10:00:00',
        'summary': 'Focus on database homework first.',
        'items': [
          {
            'taskTitle': 'Normalization HW',
            'courseName': 'Database',
            'suggestedDate': '2026-06-14',
            'suggestedTime': '15:00 – 17:00',
            'hoursNeeded': 2,
            'priority': 'high',
            'tip': 'Start with examples.',
          },
        ],
      });

      expect(plan.success, isTrue);
      expect(plan.studentName, 'Pakinam');
      expect(plan.items, hasLength(1));
      expect(plan.summary, contains('database'));
    });

    test('round-trip toJson preserves data', () {
      const original = StudyPlan(
        success: true,
        studentName: 'Student',
        generatedAt: '2026-06-12',
        summary: 'Plan summary',
        items: [
          StudyPlanItem(
            taskTitle: 'Task A',
            courseName: 'CS',
            suggestedDate: '2026-06-13',
            suggestedTime: '10:00 – 12:00',
            hoursNeeded: 2,
            priority: 'medium',
            tip: 'Tip',
          ),
        ],
      );

      final restored = StudyPlan.fromJson(original.toJson());

      expect(restored.studentName, original.studentName);
      expect(restored.items.first.taskTitle, 'Task A');
    });
  });
}
