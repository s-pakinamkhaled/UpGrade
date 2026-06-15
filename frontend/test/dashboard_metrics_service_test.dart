import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/models/dashboard_stats.dart';
import 'package:upgrade/models/task.dart';
import 'package:upgrade/services/dashboard_metrics_service.dart';

import 'helpers/task_fixtures.dart';

void main() {
  group('DashboardMetricsService', () {
    test('empty task list returns onboarding insight', () {
      final stats = DashboardMetricsService.build(
        tasks: const [],
        range: DashboardRange.last7Days,
      );

      expect(stats.totalTasks, 0);
      expect(stats.performanceLabel, 'At Risk');
      expect(
        stats.insights.first,
        contains('Sync Google Classroom'),
      );
    });

    test('counts completed, pending, and missed tasks', () {
      final now = DateTime.now();
      final stats = DashboardMetricsService.build(
        tasks: [
          makeTask(
            id: '1',
            status: TaskStatus.completed,
            deadline: now.subtract(const Duration(days: 1)),
            completedAt: now.subtract(const Duration(hours: 2)),
          ),
          makeTask(
            id: '2',
            status: TaskStatus.pending,
            deadline: now.add(const Duration(days: 1)),
          ),
          makeTask(
            id: '3',
            status: TaskStatus.pending,
            deadline: now.subtract(const Duration(days: 2)),
          ),
        ],
        range: DashboardRange.last7Days,
      );

      expect(stats.totalTasks, 3);
      expect(stats.completedTasks, 1);
      expect(stats.pendingTasks, 2);
      expect(stats.missedTasks, 1);
    });

    test('filters metrics by selected course', () {
      final stats = DashboardMetricsService.build(
        tasks: [
          makeTask(id: '1', courseName: 'Database'),
          makeTask(id: '2', courseName: 'AI'),
        ],
        range: DashboardRange.last7Days,
        selectedCourse: 'Database',
      );

      expect(stats.totalTasks, 1);
      expect(stats.selectedCourse, 'Database');
    });

    test('marks student on track with healthy completion rate', () {
      final now = DateTime.now();
      final stats = DashboardMetricsService.build(
        tasks: [
          makeTask(
            id: '1',
            status: TaskStatus.completed,
            deadline: now.add(const Duration(days: 3)),
            completedAt: now,
          ),
          makeTask(
            id: '2',
            status: TaskStatus.completed,
            deadline: now.add(const Duration(days: 4)),
            completedAt: now,
          ),
          makeTask(
            id: '3',
            status: TaskStatus.pending,
            deadline: now.add(const Duration(days: 5)),
          ),
        ],
        range: DashboardRange.last7Days,
      );

      expect(stats.completionRate, closeTo(0.666, 0.01));
      expect(stats.isOnTrack, isTrue);
      expect(stats.performanceLabel, isNot('At Risk'));
    });

    test('computes average grade from graded tasks', () {
      final stats = DashboardMetricsService.build(
        tasks: [
          makeTask(
            id: '1',
            assignedGrade: 80,
            maxPoints: 100,
          ),
          makeTask(
            id: '2',
            assignedGrade: 90,
            maxPoints: 100,
          ),
        ],
        range: DashboardRange.last7Days,
      );

      expect(stats.averageGradePct, 85);
    });

    test('ignores whitespace-only course filter', () {
      final stats = DashboardMetricsService.build(
        tasks: [makeTask(id: '1', courseName: 'Database')],
        range: DashboardRange.last7Days,
        selectedCourse: '   ',
      );

      expect(stats.totalTasks, 1);
      expect(stats.selectedCourse, isNull);
    });

    test('urgent tasks are counted separately from completed work', () {
      final stats = DashboardMetricsService.build(
        tasks: [
          makeTask(
            id: '1',
            priority: TaskPriority.urgent,
            status: TaskStatus.pending,
          ),
          makeTask(
            id: '2',
            priority: TaskPriority.low,
            status: TaskStatus.completed,
            completedAt: DateTime.now(),
          ),
        ],
        range: DashboardRange.last7Days,
      );

      expect(stats.urgentOrHighTasks, 1);
      expect(stats.completedTasks, 1);
    });
  });
}
