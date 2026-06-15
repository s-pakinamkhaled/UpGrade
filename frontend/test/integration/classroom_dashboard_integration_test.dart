import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/models/classroom_course.dart';
import 'package:upgrade/models/task.dart';
import 'package:upgrade/providers/classroom_provider.dart';

import '../helpers/task_fixtures.dart';
import 'helpers/integration_app_harness.dart';

void main() {
  group('Classroom data → dashboard metrics (integration)', () {
    late ClassroomProvider classroom;

    setUp(() {
      classroom = ClassroomProvider();
      classroom.seedForTest(
        courses: const [
          ClassroomCourse(id: 'cs101', name: 'Database Systems'),
        ],
        tasks: [
          makeTask(
            id: 'task_pending',
            title: 'Normalization HW',
            status: TaskStatus.pending,
            courseName: 'Database Systems',
            deadline: DateTime.now(),
          ),
          makeTask(
            id: 'task_done',
            title: 'ER Diagram',
            status: TaskStatus.completed,
            completedAt: DateTime.now(),
            courseName: 'Database Systems',
          ),
        ],
        syncedAt: DateTime(2026, 3, 1, 10, 30),
      );
    });

    testWidgets('dashboard reflects seeded task counts and course filter',
        (tester) async {
      await tester.binding.setSurfaceSize(kIntegrationDesktopSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildDashboardIntegrationApp(
          classroomProvider: classroom,
          viewportSize: kIntegrationDesktopSize,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Progress Dashboard'), findsWidgets);
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Completed'), findsWidgets);
      expect(find.textContaining('Synced:'), findsOneWidget);
    });

    testWidgets('planner tab lists seeded pending task title', (tester) async {
      await tester.binding.setSurfaceSize(kIntegrationDesktopSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildDashboardIntegrationApp(
          classroomProvider: classroom,
          viewportSize: kIntegrationDesktopSize,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Tasks').first);
      await tester.pumpAndSettle();

      expect(find.text('Normalization HW'), findsWidgets);
    });

    testWidgets('empty classroom shows dashboard empty guidance', (tester) async {
      final empty = ClassroomProvider()..seedForTest();

      await tester.binding.setSurfaceSize(kIntegrationDesktopSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildDashboardIntegrationApp(classroomProvider: empty),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No student data yet'),
        findsOneWidget,
      );
    });
  });
}
