import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/models/classroom_course.dart';
import 'package:upgrade/models/classroom_assignment.dart';
import 'package:upgrade/models/classroom_submission.dart';
import 'package:upgrade/models/task.dart';
import 'package:upgrade/services/classroom_mapper_service.dart';

void main() {
  group('ClassroomMapperService', () {
    final course = ClassroomCourse(
      id: 'c1',
      name: 'Math 101',
      section: 'A',
      description: 'Algebra',
    );

    test('mapAll returns empty tasks when given empty lists', () {
      final result = ClassroomMapperService.mapAll(
        courses: [],
        assignments: [],
        submissions: [],
      );
      expect(result.courses, isEmpty);
      expect(result.tasks, isEmpty);
      expect(result.assignments, isEmpty);
      expect(result.submissions, isEmpty);
    });

    test('mapAll returns courses and assignments unchanged', () {
      final assignments = [
        ClassroomAssignment(
          id: 'a1',
          courseId: 'c1',
          title: 'Homework 1',
          dueDate: DateTime.now().add(const Duration(days: 2)),
          maxPoints: 100,
        ),
      ];
      final result = ClassroomMapperService.mapAll(
        courses: [course],
        assignments: assignments,
        submissions: [],
      );
      expect(result.courses, [course]);
      expect(result.assignments, assignments);
    });

    test('mapAll produces one task per assignment with correct fields', () {
      final due = DateTime.now().add(const Duration(days: 5));
      final assignments = [
        ClassroomAssignment(
          id: 'a1',
          courseId: 'c1',
          title: 'Essay',
          description: 'Write 500 words',
          dueDate: due,
          maxPoints: 50,
        ),
      ];
      final result = ClassroomMapperService.mapAll(
        courses: [course],
        assignments: assignments,
        submissions: [],
      );
      expect(result.tasks.length, 1);
      final task = result.tasks.first;
      expect(task.id, 'a1');
      expect(task.title, 'Essay');
      expect(task.description, 'Write 500 words');
      expect(task.courseId, 'c1');
      expect(task.courseName, 'Math 101');
      expect(task.maxPoints, 50);
      expect(task.deadline, due);
      expect(task.status, TaskStatus.pending);
    });

    test('mapAll marks task completed when submission is RETURNED', () {
      final assignments = [
        ClassroomAssignment(
          id: 'a1',
          courseId: 'c1',
          title: 'Done work',
          dueDate: DateTime.now().add(const Duration(days: 1)),
          maxPoints: 20,
        ),
      ];
      final submissions = [
        ClassroomSubmission(
          id: 's1',
          courseId: 'c1',
          assignmentId: 'a1',
          state: 'RETURNED',
          assignedGrade: 18.0,
        ),
      ];
      final result = ClassroomMapperService.mapAll(
        courses: [course],
        assignments: assignments,
        submissions: submissions,
      );
      expect(result.tasks.length, 1);
      expect(result.tasks.first.status, TaskStatus.completed);
      expect(result.tasks.first.assignedGrade, 18.0);
    });

    test('mapAll marks task completed when submission is TURNED_IN', () {
      final assignments = [
        ClassroomAssignment(
          id: 'a1',
          courseId: 'c1',
          title: 'Submitted',
          dueDate: DateTime.now().add(const Duration(days: 1)),
          maxPoints: 10,
        ),
      ];
      final submissions = [
        ClassroomSubmission(
          id: 's1',
          courseId: 'c1',
          assignmentId: 'a1',
          state: 'TURNED_IN',
        ),
      ];
      final result = ClassroomMapperService.mapAll(
        courses: [course],
        assignments: assignments,
        submissions: submissions,
      );
      expect(result.tasks.first.status, TaskStatus.completed);
    });

    test('mapAll marks task missed when deadline passed and not submitted', () {
      final pastDue = DateTime.now().subtract(const Duration(days: 1));
      final assignments = [
        ClassroomAssignment(
          id: 'a1',
          courseId: 'c1',
          title: 'Late',
          dueDate: pastDue,
          maxPoints: 30,
        ),
      ];
      final result = ClassroomMapperService.mapAll(
        courses: [course],
        assignments: assignments,
        submissions: [],
      );
      expect(result.tasks.length, 1);
      expect(result.tasks.first.status, TaskStatus.missed);
    });

    test('mapAll estimates time from maxPoints (30 for small, 60 for medium, 90 for large)', () {
      final due = DateTime.now().add(const Duration(days: 3));
      final assignments = [
        ClassroomAssignment(id: 'a1', courseId: 'c1', title: 'Small', dueDate: due, maxPoints: 20),
        ClassroomAssignment(id: 'a2', courseId: 'c1', title: 'Medium', dueDate: due, maxPoints: 50),
        ClassroomAssignment(id: 'a3', courseId: 'c1', title: 'Large', dueDate: due, maxPoints: 100),
      ];
      final result = ClassroomMapperService.mapAll(
        courses: [course],
        assignments: assignments,
        submissions: [],
      );
      expect(result.tasks.length, 3);
      expect(result.tasks[0].estimatedMinutes, 30);
      expect(result.tasks[1].estimatedMinutes, 60);
      expect(result.tasks[2].estimatedMinutes, 90);
    });

    test('mapFromRawResponse parses raw sync response into courses and tasks', () {
      final raw = {
        'data': [
          {
            'course': {'id': 'c1', 'name': 'Physics'},
            'works': [
              {
                'id': 'w1',
                'courseId': 'c1',
                'title': 'Lab 1',
                'dueDate': null,
                'maxPoints': 25,
              },
            ],
            'submissions': [
              {'id': 'sub1', 'courseId': 'c1', 'courseWorkId': 'w1', 'state': 'CREATED'},
            ],
          },
        ],
      };
      final result = ClassroomMapperService.mapFromRawResponse(raw);
      expect(result.courses.length, 1);
      expect(result.courses.first.id, 'c1');
      expect(result.courses.first.name, 'Physics');
      expect(result.tasks.length, 1);
      expect(result.tasks.first.title, 'Lab 1');
      expect(result.tasks.first.courseName, 'Physics');
    });

    test('mapFromRawResponse handles empty data', () {
      final result = ClassroomMapperService.mapFromRawResponse({'data': []});
      expect(result.courses, isEmpty);
      expect(result.tasks, isEmpty);
    });

    test('mapFromRawResponse handles missing data key', () {
      final result = ClassroomMapperService.mapFromRawResponse({});
      expect(result.courses, isEmpty);
      expect(result.tasks, isEmpty);
    });
  });
}
