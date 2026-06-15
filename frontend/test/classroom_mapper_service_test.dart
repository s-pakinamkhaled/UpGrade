import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/models/classroom_assignment.dart';
import 'package:upgrade/models/classroom_course.dart';
import 'package:upgrade/models/classroom_submission.dart';
import 'package:upgrade/models/task.dart';
import 'package:upgrade/services/classroom_mapper_service.dart';

void main() {
  group('ClassroomMapperService', () {
    const course = ClassroomCourse(
      id: 'course_1',
      name: 'Database Systems',
    );

    test('maps pending assignment due within 72 hours to high priority', () {
      final deadline = DateTime.now().add(const Duration(days: 2));
      final tasks = ClassroomMapperService.mapToTasks(
        course: course,
        assignments: [
          ClassroomAssignment(
            id: 'a1',
            courseId: 'course_1',
            title: 'Normalization HW',
            dueDate: deadline,
            maxPoints: 40,
          ),
        ],
        submissions: const [],
      );

      expect(tasks.length, 1);
      expect(tasks.first.status, TaskStatus.pending);
      expect(tasks.first.priority, TaskPriority.high);
      expect(tasks.first.estimatedMinutes, 60);
      expect(tasks.first.courseName, 'Database Systems');
    });

    test('maps submitted assignment to completed low-priority task', () {
      final deadline = DateTime.now().add(const Duration(hours: 10));
      final tasks = ClassroomMapperService.mapToTasks(
        course: course,
        assignments: [
          ClassroomAssignment(
            id: 'a1',
            courseId: 'course_1',
            title: 'Quiz 1',
            dueDate: deadline,
            maxPoints: 20,
          ),
        ],
        submissions: [
          ClassroomSubmission(
            id: 's1',
            courseId: 'course_1',
            assignmentId: 'a1',
            state: 'TURNED_IN',
            updateTime: DateTime.now(),
          ),
        ],
      );

      expect(tasks.first.status, TaskStatus.completed);
      expect(tasks.first.priority, TaskPriority.low);
    });

    test('maps overdue unsubmitted assignment to missed task', () {
      final tasks = ClassroomMapperService.mapToTasks(
        course: course,
        assignments: [
          ClassroomAssignment(
            id: 'a1',
            courseId: 'course_1',
            title: 'Late Lab',
            dueDate: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ],
        submissions: const [],
      );

      expect(tasks.first.status, TaskStatus.missed);
    });

    test('mapAll aggregates tasks across courses', () {
      const courseTwo = ClassroomCourse(id: 'course_2', name: 'AI');
      final result = ClassroomMapperService.mapAll(
        courses: const [course, courseTwo],
        assignments: [
          ClassroomAssignment(
            id: 'a1',
            courseId: 'course_1',
            title: 'HW1',
            dueDate: DateTime.now().add(const Duration(days: 2)),
          ),
          ClassroomAssignment(
            id: 'a2',
            courseId: 'course_2',
            title: 'Project',
            dueDate: DateTime.now().add(const Duration(days: 3)),
          ),
        ],
        submissions: const [],
      );

      expect(result.tasks.length, 2);
      expect(result.courses.length, 2);
    });

    test('mapFromRawResponse parses classroom sync payload', () {
      final mapped = ClassroomMapperService.mapFromRawResponse({
        'data': [
          {
            'course': {
              'id': 'course_1',
              'name': 'Database Systems',
            },
            'works': [
              {
                'id': 'a1',
                'courseId': 'course_1',
                'title': 'ER Diagram',
                'maxPoints': 10,
              },
            ],
            'submissions': [],
          },
        ],
      });

      expect(mapped.courses.length, 1);
      expect(mapped.tasks.length, 1);
      expect(mapped.tasks.first.title, 'ER Diagram');
    });
  });
}
