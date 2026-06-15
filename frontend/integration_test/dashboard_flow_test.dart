import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:upgrade/models/classroom_course.dart';
import 'package:upgrade/models/task.dart';
import 'package:upgrade/providers/classroom_provider.dart';

import '../test/helpers/task_fixtures.dart';
import '../test/integration/helpers/integration_app_harness.dart';

/// Device/desktop integration entry point (`flutter test integration_test/`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('UpGrade dashboard integration (device runner)', () {
    testWidgets('seeded tasks appear on dashboard and planner tab', (tester) async {
      await tester.binding.setSurfaceSize(kIntegrationDesktopSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final classroom = ClassroomProvider()
        ..seedForTest(
          courses: const [ClassroomCourse(id: 'cs101', name: 'Algorithms')],
          tasks: [
            makeTask(
              id: 'integration_task',
              title: 'Graph traversal lab',
              status: TaskStatus.pending,
              courseName: 'Algorithms',
            ),
          ],
        );

      await tester.pumpWidget(
        buildDashboardIntegrationApp(
          classroomProvider: classroom,
          viewportSize: kIntegrationDesktopSize,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Progress Dashboard'), findsWidgets);
      expect(find.text('Graph traversal lab'), findsNothing);

      await tester.tap(find.text('My Tasks').first);
      await tester.pumpAndSettle();

      expect(find.text('Graph traversal lab'), findsWidgets);
    });
  });
}
