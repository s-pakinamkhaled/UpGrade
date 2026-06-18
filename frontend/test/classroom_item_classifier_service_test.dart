import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/models/task.dart';
import 'package:upgrade/services/classroom_item_classifier_service.dart';

Task _classroomTask({
  required String title,
  DateTime? deadline,
  bool hasRealDeadline = true,
}) {
  final due = deadline ?? DateTime.now().add(const Duration(days: 3));
  return Task(
    id: 'gc_${title.hashCode}',
    title: title,
    description: '',
    deadline: due,
    courseId: 'course_1',
    courseName: 'IoT Applications Development',
    priority: TaskPriority.medium,
    status: TaskStatus.pending,
    estimatedMinutes: 60,
    source: 'google_classroom',
    hasRealDeadline: hasRealDeadline,
    deadlineSource: 'classroom',
  );
}

void main() {
  group('ClassroomItemClassifierService grade filtering', () {
    test('excludes grade category rows from actionable tasks', () {
      final titles = [
        'Project Phase 1 (Grades)',
        'Lecture Participation',
        'Phase 1 (20)',
        'Project Phase#3',
        'Project Phase#2',
        'Project Phase#1',
        'Assignment#3',
        'Assignment#2',
        'Assignment#1',
        'Project Total (20%)',
      ];

      for (final title in titles) {
        final classified =
            ClassroomItemClassifierService.classifyTask(_classroomTask(title: title));
        expect(
          ClassroomItemClassifierService.isActionableForAI(classified),
          isFalse,
          reason: '$title should not be schedulable',
        );
        expect(classified.isGradeRelated || classified.isDashboardOnly, isTrue);
      }
    });

    test('keeps real deliverables actionable', () {
      final titles = [
        'Assignment#2 [Bonus]',
        'Phase#3: Edge-to-Cloud Integration',
        'MVP Delivery',
        'Final Submissions',
        'Project Team Formation',
      ];

      for (final title in titles) {
        final classified =
            ClassroomItemClassifierService.classifyTask(_classroomTask(title: title));
        expect(
          ClassroomItemClassifierService.isActionableForAI(classified),
          isTrue,
          reason: '$title should remain a task',
        );
      }
    });
    test('ignores dated Classroom rows without deliverable signals', () {
      final classified = ClassroomItemClassifierService.classifyTask(
        _classroomTask(title: 'Week 6 overview'),
      );

      expect(ClassroomItemClassifierService.isActionableForAI(classified), isFalse);
    });
  });
}
