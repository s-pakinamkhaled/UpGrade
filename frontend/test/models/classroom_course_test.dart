import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/models/classroom_course.dart';

void main() {
  group('ClassroomCourse', () {
    test('fromJson parses full json correctly', () {
      final json = {
        'id': 'course-1',
        'name': 'Algebra 101',
        'section': 'Section A',
        'description': 'Intro to algebra',
      };
      final course = ClassroomCourse.fromJson(json);
      expect(course.id, 'course-1');
      expect(course.name, 'Algebra 101');
      expect(course.section, 'Section A');
      expect(course.description, 'Intro to algebra');
    });

    test('fromJson uses defaults for missing fields', () {
      final json = {
        'id': 'course-2',
      };
      final course = ClassroomCourse.fromJson(json);
      expect(course.name, 'Unnamed course');
      expect(course.section, isNull);
      expect(course.description, isNull);
    });

    test('toJson then fromJson round-trip preserves data', () {
      const course = ClassroomCourse(
        id: 'c1',
        name: 'Physics',
        section: 'B',
        description: 'Mechanics',
      );
      final json = course.toJson();
      final restored = ClassroomCourse.fromJson(json);
      expect(restored.id, course.id);
      expect(restored.name, course.name);
      expect(restored.section, course.section);
      expect(restored.description, course.description);
    });
  });
}
