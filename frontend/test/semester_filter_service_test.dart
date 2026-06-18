import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/services/semester_filter_service.dart';

void main() {
  group('SemesterFilterService', () {
    test('detects Spring 2026 from course name', () {
      final semester = SemesterFilterService.detectFromCourse({
        'name': 'Database Systems - Spring 2026',
      });

      expect(semester, isNotNull);
      expect(semester!.label, 'Spring 2026');
    });

    test('detects year-term pattern', () {
      final semester = SemesterFilterService.detectFromCourse({
        'section': '2026 Fall',
      });

      expect(semester, isNotNull);
      expect(semester!.label, 'Fall 2026');
    });

    test('extractSemesters deduplicates and sorts newest first', () {
      final semesters = SemesterFilterService.extractSemesters([
        {'name': 'AI - Spring 2025'},
        {'name': 'Database - Fall 2026'},
        {'name': 'OS - Fall 2026'},
      ]);

      expect(semesters.length, 2);
      expect(semesters.first.label, 'Fall 2026');
      expect(semesters.last.label, 'Spring 2025');
    });

    test('extractSemesters adds unknown bucket when needed', () {
      final semesters = SemesterFilterService.extractSemesters([
        {'name': 'Intro to Programming'},
        {'name': 'Database - Fall 2026'},
      ]);

      expect(
        semesters.any((s) => s.id == SemesterFilterService.unknownSemesterId),
        isTrue,
      );
    });

    test('extractSemestersOrFallback returns unknown when empty', () {
      final semesters = SemesterFilterService.extractSemestersOrFallback([]);

      expect(semesters.length, 1);
      expect(semesters.first.isUnknown, isTrue);
    });

    test('selectDefaultSemesterId prefers saved valid semester', () {
      final semesters = SemesterFilterService.extractSemesters([
        {'name': 'Database - Fall 2026'},
        {'name': 'AI - Spring 2025'},
      ]);

      final selected = SemesterFilterService.selectDefaultSemesterId(
        semesters,
        savedSemesterId: 'spring_2025',
      );

      expect(selected, 'spring_2025');
    });

    test('detects Fall 24 shorthand as Fall 2024', () {
      final semester = SemesterFilterService.detectFromCourse({
        'name': 'Embedded Systems - Fall 24',
      });

      expect(semester, isNotNull);
      expect(semester!.label, 'Fall 2024');
      expect(semester.id, 'fall_2024');
    });

    test('matchesSemester routes unknown courses to unknown bucket only', () {
      final unknownCourse = {'name': 'Untitled course'};

      expect(
        SemesterFilterService.matchesSemester(
          course: unknownCourse,
          semesterId: SemesterFilterService.unknownSemesterId,
        ),
        isTrue,
      );
      expect(
        SemesterFilterService.matchesSemester(
          course: unknownCourse,
          semesterId: 'spring_2026',
        ),
        isFalse,
      );
    });

    test('matchesSemester excludes old semester from Spring 2026 sync', () {
      expect(
        SemesterFilterService.matchesSemester(
          course: {'name': 'Embedded Systems - Fall 24'},
          semesterId: 'spring_2026',
        ),
        isFalse,
      );
      expect(
        SemesterFilterService.matchesSemester(
          course: {'name': 'Database Systems - Spring 2026'},
          semesterId: 'spring_2026',
        ),
        isTrue,
      );
    });

    test('detectFromCourse ignores malicious markup in course fields', () {
      final semester = SemesterFilterService.detectFromCourse({
        'name': '<img src=x onerror=alert(1)> Spring 2026',
      });

      expect(semester, isNotNull);
      expect(semester!.label, 'Spring 2026');
      expect(semester.id, isNot(contains('<')));
    });
  });
}
