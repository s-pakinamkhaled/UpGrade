import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/models/task.dart';

void main() {
  group('Task model security / resilience', () {
    test('fromJson survives script-like title without throwing', () {
      final task = Task.fromJson({
        'id': 'x1',
        'title': '<script>alert("xss")</script>',
        'deadline': '2026-06-01T00:00:00.000',
        'courseId': 'c1',
        'courseName': 'Database',
      });

      expect(task.title, contains('<script>'));
      expect(task.toJson()['title'], isA<String>());
    });

    test('fromJson handles missing and malformed fields safely', () {
      final task = Task.fromJson({});

      expect(task.id, '');
      expect(task.title, '');
      expect(task.estimatedMinutes, 30);
      expect(task.status, TaskStatus.pending);
    });

    test('fromJson ignores invalid numeric grades', () {
      final task = Task.fromJson({
        'id': '1',
        'title': 'Graded',
        'deadline': '2026-06-01T00:00:00.000',
        'courseId': 'c1',
        'courseName': 'Database',
        'assignedGrade': 'not-a-number',
        'maxPoints': 'abc',
      });

      expect(task.assignedGrade, isNull);
      expect(task.maxPoints, isNull);
    });

    test('copyWith does not leak previous completedAt when clearing', () {
      final completed = Task(
        id: '1',
        title: 'Done',
        deadline: DateTime.now(),
        courseId: 'c1',
        courseName: 'Database',
        status: TaskStatus.completed,
        estimatedMinutes: 30,
        completedAt: DateTime.now(),
      );

      final reopened = completed.copyWith(
        status: TaskStatus.pending,
        clearCompletedAt: true,
      );

      expect(reopened.completedAt, isNull);
      expect(reopened.status, TaskStatus.pending);
    });
  });
}
