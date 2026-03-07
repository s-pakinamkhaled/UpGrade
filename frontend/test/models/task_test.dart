import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/models/task.dart';

void main() {
  group('Task', () {
    test('fromJson parses full json correctly', () {
      final json = {
        'id': 't1',
        'title': 'Math homework',
        'description': 'Chapter 5',
        'deadline': '2025-12-31T23:59:00.000',
        'courseId': 'c1',
        'courseName': 'Math 101',
        'priority': 'high',
        'status': 'pending',
        'estimatedMinutes': 60,
        'scheduledTime': '2025-06-15T10:00:00.000',
        'completedAt': null,
        'assignedGrade': 85.0,
        'maxPoints': 100,
      };
      final task = Task.fromJson(json);
      expect(task.id, 't1');
      expect(task.title, 'Math homework');
      expect(task.description, 'Chapter 5');
      expect(task.courseId, 'c1');
      expect(task.courseName, 'Math 101');
      expect(task.priority, TaskPriority.high);
      expect(task.status, TaskStatus.pending);
      expect(task.estimatedMinutes, 60);
      expect(task.assignedGrade, 85.0);
      expect(task.maxPoints, 100);
      expect(task.deadline.year, 2025);
      expect(task.deadline.month, 12);
      expect(task.deadline.day, 31);
      expect(task.scheduledTime?.year, 2025);
      expect(task.scheduledTime?.month, 6);
      expect(task.scheduledTime?.day, 15);
    });

    test('fromJson uses defaults for missing optional fields', () {
      final json = {
        'id': 't2',
        'title': 'Essay',
        'deadline': '2025-07-01T12:00:00.000',
        'courseId': 'c2',
        'courseName': 'English',
      };
      final task = Task.fromJson(json);
      expect(task.description, isNull);
      expect(task.priority, TaskPriority.medium);
      expect(task.status, TaskStatus.pending);
      expect(task.estimatedMinutes, 30);
      expect(task.scheduledTime, isNull);
      expect(task.completedAt, isNull);
      expect(task.assignedGrade, isNull);
      expect(task.maxPoints, isNull);
    });

    test('fromJson parses priority strings correctly', () {
      expect(Task.fromJson({'id': 'x', 'title': 'x', 'deadline': '2025-01-01', 'courseId': 'c', 'courseName': 'C', 'priority': 'urgent'}).priority, TaskPriority.urgent);
      expect(Task.fromJson({'id': 'x', 'title': 'x', 'deadline': '2025-01-01', 'courseId': 'c', 'courseName': 'C', 'priority': 'low'}).priority, TaskPriority.low);
      expect(Task.fromJson({'id': 'x', 'title': 'x', 'deadline': '2025-01-01', 'courseId': 'c', 'courseName': 'C', 'priority': 'unknown'}).priority, TaskPriority.medium);
    });

    test('fromJson parses status strings correctly', () {
      expect(Task.fromJson({'id': 'x', 'title': 'x', 'deadline': '2025-01-01', 'courseId': 'c', 'courseName': 'C', 'status': 'completed'}).status, TaskStatus.completed);
      expect(Task.fromJson({'id': 'x', 'title': 'x', 'deadline': '2025-01-01', 'courseId': 'c', 'courseName': 'C', 'status': 'missed'}).status, TaskStatus.missed);
      expect(Task.fromJson({'id': 'x', 'title': 'x', 'deadline': '2025-01-01', 'courseId': 'c', 'courseName': 'C', 'status': 'inProgress'}).status, TaskStatus.inProgress);
    });

    test('toJson then fromJson round-trip preserves data', () {
      final task = Task(
        id: 't3',
        title: 'Lab report',
        description: 'Physics',
        deadline: DateTime.utc(2025, 8, 20),
        courseId: 'c3',
        courseName: 'Physics',
        priority: TaskPriority.urgent,
        status: TaskStatus.inProgress,
        estimatedMinutes: 45,
        scheduledTime: DateTime.utc(2025, 8, 19, 14, 0),
        assignedGrade: 90.0,
        maxPoints: 100,
      );
      final json = task.toJson();
      final restored = Task.fromJson(json);
      expect(restored.id, task.id);
      expect(restored.title, task.title);
      expect(restored.priority, task.priority);
      expect(restored.status, task.status);
      expect(restored.estimatedMinutes, task.estimatedMinutes);
      expect(restored.assignedGrade, task.assignedGrade);
      expect(restored.maxPoints, task.maxPoints);
    });

    test('isOverdue is true when deadline passed and status is not completed', () {
      final pastDeadline = DateTime.now().subtract(const Duration(days: 1));
      final task = Task(
        id: 't4',
        title: 'Overdue task',
        deadline: pastDeadline,
        courseId: 'c',
        courseName: 'Course',
        status: TaskStatus.pending,
        estimatedMinutes: 30,
      );
      expect(task.isOverdue, isTrue);
    });

    test('isOverdue is false when task is completed even if deadline passed', () {
      final pastDeadline = DateTime.now().subtract(const Duration(days: 1));
      final task = Task(
        id: 't5',
        title: 'Done task',
        deadline: pastDeadline,
        courseId: 'c',
        courseName: 'Course',
        status: TaskStatus.completed,
        estimatedMinutes: 30,
      );
      expect(task.isOverdue, isFalse);
    });

    test('TaskPriorityExtension.label returns correct labels', () {
      expect(TaskPriority.low.label, 'Low');
      expect(TaskPriority.medium.label, 'Medium');
      expect(TaskPriority.high.label, 'High');
      expect(TaskPriority.urgent.label, 'Urgent');
    });
  });
}
