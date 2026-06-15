import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/models/task.dart';

void main() {
  group('Task model', () {
    test('fromJson and toJson round-trip', () {
      final json = {
        'id': 'task_1',
        'title': 'Database Project',
        'deadline': '2026-06-20T18:00:00.000',
        'courseId': 'cs101',
        'courseName': 'Database',
        'priority': 'high',
        'status': 'inProgress',
        'estimatedMinutes': 90,
        'updatedAt': '2026-06-01T10:00:00.000',
      };

      final task = Task.fromJson(json);
      final encoded = task.toJson();

      expect(task.id, 'task_1');
      expect(task.priority, TaskPriority.high);
      expect(task.status, TaskStatus.inProgress);
      expect(encoded['title'], 'Database Project');
    });

    test('copyWith updates status and clears completedAt', () {
      final original = Task(
        id: '1',
        title: 'Task',
        deadline: DateTime.now().add(const Duration(days: 1)),
        courseId: 'c1',
        courseName: 'Database',
        status: TaskStatus.completed,
        estimatedMinutes: 30,
        completedAt: DateTime.now(),
      );

      final reopened = original.copyWith(
        status: TaskStatus.pending,
        clearCompletedAt: true,
      );

      expect(reopened.status, TaskStatus.pending);
      expect(reopened.completedAt, isNull);
    });

    test('isOverdue is true for past incomplete tasks', () {
      final overdue = Task(
        id: '1',
        title: 'Late task',
        deadline: DateTime.now().subtract(const Duration(days: 1)),
        courseId: 'c1',
        courseName: 'Database',
        estimatedMinutes: 30,
      );

      expect(overdue.isOverdue, isTrue);
    });

    test('isOverdue is false for completed tasks', () {
      final done = Task(
        id: '1',
        title: 'Done task',
        deadline: DateTime.now().subtract(const Duration(days: 1)),
        courseId: 'c1',
        courseName: 'Database',
        status: TaskStatus.completed,
        estimatedMinutes: 30,
        completedAt: DateTime.now(),
      );

      expect(done.isOverdue, isFalse);
    });
  });

  group('TaskPriorityExtension', () {
    test('labels map correctly', () {
      expect(TaskPriority.urgent.label, 'Urgent');
      expect(TaskPriority.medium.label, 'Medium');
    });
  });
}
