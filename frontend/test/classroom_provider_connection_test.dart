import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/models/classroom_course.dart';
import 'package:upgrade/models/task.dart';
import 'package:upgrade/providers/classroom_provider.dart';

void main() {
  group('ClassroomProvider Google Classroom connection status', () {
    test('detects synced Classroom courses', () {
      expect(
        ClassroomProvider.hasGoogleClassroomData(
          const [
            ClassroomCourse(id: 'manual_1', name: 'My course'),
          ],
          const [],
        ),
        isFalse,
      );

      expect(
        ClassroomProvider.hasGoogleClassroomData(
          const [
            ClassroomCourse(id: '123456789', name: 'CS101'),
          ],
          const [],
        ),
        isTrue,
      );
    });

    test('detects synced Classroom assignments without courses', () {
      expect(
        ClassroomProvider.hasGoogleClassroomData(
          const [],
          [
            Task(
              id: 'a1',
              title: 'Homework',
              deadline: DateTime(2026, 6, 1),
              courseId: '123',
              courseName: 'Math',
              estimatedMinutes: 60,
              source: 'google_classroom',
            ),
          ],
        ),
        isTrue,
      );
    });

    test('googleClassroomConnected reflects in-memory synced data', () {
      final provider = ClassroomProvider()
        ..seedForTest(
          courses: const [
            ClassroomCourse(id: 'course_abc', name: 'Database'),
          ],
        );

      expect(provider.googleClassroomConnected, isTrue);
    });
  });
}
