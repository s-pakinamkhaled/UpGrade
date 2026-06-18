import '../models/dashboard_stats.dart';
import '../models/task.dart';

class DashboardMetricsService {
  static DashboardStats build({
    required List<Task> tasks,
    required DashboardRange range,
    String? selectedCourse,
  }) {
    final normalizedCourse = _normalizeSelectedCourse(selectedCourse);
    final filteredAll = normalizedCourse == null
        ? List<Task>.from(tasks)
        : tasks.where((t) => _courseName(t) == normalizedCourse).toList();
    final filteredTasks = filteredAll.where(_countsAsTaskMetric).toList();
    final taskMetricItems = tasks.where(_countsAsTaskMetric).toList();

    final now = DateTime.now();
    final today = _dateOnly(now);
    final rangeStart = today.subtract(Duration(days: range.days - 1));
    final previousEnd = rangeStart.subtract(const Duration(days: 1));
    final previousStart = previousEnd.subtract(Duration(days: range.days - 1));

    final totalTasks = filteredTasks.length;
    final completedTasks =
        filteredTasks.where((t) => t.status == TaskStatus.completed).length;
    final pendingTasks =
        filteredTasks.where((t) => t.status == TaskStatus.pending).length;
    final inProgressTasks =
        filteredTasks.where((t) => t.status == TaskStatus.inProgress).length;
    final missedTasks = filteredTasks.where((t) => _isMissed(t, now)).length;

    final dueToday = filteredTasks
        .where(
          (t) =>
              _dateOnly(t.deadline) == today &&
              t.hasRealDeadline &&
              t.status != TaskStatus.completed,
        )
        .length;

    final upcoming48Hours = filteredTasks.where((t) {
      if (t.status == TaskStatus.completed) return false;
      return t.hasRealDeadline &&
          t.deadline.isAfter(now) &&
          t.deadline.isBefore(now.add(const Duration(hours: 48)));
    }).length;

    final urgentOrHighTasks = filteredTasks
        .where(
          (t) =>
              (t.priority == TaskPriority.urgent ||
                  t.priority == TaskPriority.high) &&
              t.status != TaskStatus.completed,
        )
        .length;

    final completionRate = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

    final dailyPoints = _buildDailyPoints(
        filteredTasks: filteredTasks, start: rangeStart, days: range.days);

    final studyHoursThisRange = dailyPoints.fold<double>(
      0,
      (sum, p) => sum + (p.completedMinutes / 60.0),
    );

    final studyHoursPreviousRange =
        _completedMinutesInWindow(filteredTasks, previousStart, previousEnd) /
            60.0;

    final completionRateThisRange =
        _completionRateByDueWindow(filteredTasks, rangeStart, today);
    final completionRatePreviousRange =
        _completionRateByDueWindow(filteredTasks, previousStart, previousEnd);

    final completionRateChangePct = _percentageChange(
      completionRateThisRange * 100,
      completionRatePreviousRange * 100,
    );

    final studyHoursChangePct = _percentageChange(
      studyHoursThisRange,
      studyHoursPreviousRange,
    );

    final averageGradePct = _averageGrade(filteredAll);

    final courseProgress = _buildCourseProgress(taskMetricItems, tasks);
    final focusCourse = _pickFocusCourse(courseProgress);

    final performanceLabel = _performanceLabel(
      completionRate: completionRate,
      missedTasks: missedTasks,
      dueToday: dueToday,
    );

    final isOnTrack =
        missedTasks == 0 && completionRate >= 0.6 && dueToday <= 1;

    final insights = _buildSimpleInsights(
      totalTasks: totalTasks,
      completedTasks: completedTasks,
      pendingTasks: pendingTasks,
      inProgressTasks: inProgressTasks,
      missedTasks: missedTasks,
      dueToday: dueToday,
      upcoming48Hours: upcoming48Hours,
      completionRate: completionRate,
      completionRateChangePct: completionRateChangePct,
      studyHoursThisRange: studyHoursThisRange,
      studyHoursChangePct: studyHoursChangePct,
      averageGradePct: averageGradePct,
      focusCourse: focusCourse,
    );

    return DashboardStats(
      totalTasks: totalTasks,
      completedTasks: completedTasks,
      pendingTasks: pendingTasks,
      inProgressTasks: inProgressTasks,
      missedTasks: missedTasks,
      dueToday: dueToday,
      upcoming48Hours: upcoming48Hours,
      urgentOrHighTasks: urgentOrHighTasks,
      completionRate: completionRate,
      completionRateThisRange: completionRateThisRange,
      completionRatePreviousRange: completionRatePreviousRange,
      completionRateChangePct: completionRateChangePct,
      studyHoursThisRange: studyHoursThisRange,
      studyHoursPreviousRange: studyHoursPreviousRange,
      studyHoursChangePct: studyHoursChangePct,
      averageGradePct: averageGradePct,
      performanceLabel: performanceLabel,
      isOnTrack: isOnTrack,
      focusCourse: focusCourse,
      selectedCourse: normalizedCourse,
      range: range,
      dailyPoints: dailyPoints,
      courseProgress: courseProgress,
      insights: insights,
    );
  }

  static List<DashboardDayPoint> _buildDailyPoints({
    required List<Task> filteredTasks,
    required DateTime start,
    required int days,
  }) {
    final points = <DashboardDayPoint>[];

    final now = DateTime.now();
    for (var i = 0; i < days; i++) {
      final day = start.add(Duration(days: i));
      final dueTasks = filteredTasks
          .where((t) => t.hasRealDeadline && _dateOnly(t.deadline) == day)
          .toList();

      final dueCompleted =
          dueTasks.where((t) => t.status == TaskStatus.completed).length;
      final dueMissed = dueTasks.where((t) => _isMissed(t, now)).length;
      final duePending = dueTasks
          .where(
            (t) =>
                t.status == TaskStatus.pending ||
                t.status == TaskStatus.inProgress,
          )
          .length;

      final completedTasks = filteredTasks.where((t) {
        if (t.status != TaskStatus.completed) return false;
        return _completionDay(t) == day;
      }).toList();

      final completedMinutes = completedTasks.fold<int>(
        0,
        (sum, t) => sum + t.estimatedMinutes,
      );

      points.add(
        DashboardDayPoint(
          date: day,
          dueTasks: dueTasks.length,
          dueCompleted: dueCompleted,
          duePending: duePending,
          dueMissed: dueMissed,
          completedTasks: completedTasks.length,
          completedMinutes: completedMinutes,
        ),
      );
    }

    return points;
  }

  static int _completedMinutesInWindow(
    List<Task> tasks,
    DateTime start,
    DateTime end,
  ) {
    return tasks.where((t) => t.status == TaskStatus.completed).where((t) {
      final completionDate = _completionDay(t);
      return !completionDate.isBefore(start) && !completionDate.isAfter(end);
    }).fold<int>(0, (sum, t) => sum + t.estimatedMinutes);
  }

  static double _completionRateByDueWindow(
    List<Task> tasks,
    DateTime start,
    DateTime end,
  ) {
    final dueWindow = tasks.where((t) {
      final deadline = _dateOnly(t.deadline);
      return t.hasRealDeadline &&
          !deadline.isBefore(start) &&
          !deadline.isAfter(end);
    }).toList();

    if (dueWindow.isEmpty) return 0.0;
    final completed =
        dueWindow.where((t) => t.status == TaskStatus.completed).length;
    return completed / dueWindow.length;
  }

  /// Returns a map of course name -> (averageGradePct, gradedItemCount),
  /// computed from every item that carries a real grade.
  static Map<String, (double, int)> _gradeByCourse(List<Task> tasks) {
    final sums = <String, double>{};
    final counts = <String, int>{};

    for (final task in tasks) {
      if (task.assignedGrade == null ||
          task.maxPoints == null ||
          task.maxPoints! <= 0) {
        continue;
      }
      final name = _courseName(task);
      final pct = (task.assignedGrade! / task.maxPoints!) * 100;
      sums[name] = (sums[name] ?? 0) + pct;
      counts[name] = (counts[name] ?? 0) + 1;
    }

    final result = <String, (double, int)>{};
    for (final entry in counts.entries) {
      result[entry.key] = (sums[entry.key]! / entry.value, entry.value);
    }
    return result;
  }

  static double? _averageGrade(List<Task> tasks) {
    final graded = tasks
        .where(
          (t) =>
              t.assignedGrade != null &&
              t.maxPoints != null &&
              t.maxPoints! > 0,
        )
        .toList();

    if (graded.isEmpty) return null;

    var sum = 0.0;
    for (final task in graded) {
      sum += (task.assignedGrade! / task.maxPoints!) * 100;
    }
    return sum / graded.length;
  }

  static List<CourseProgressStat> _buildCourseProgress(
    List<Task> tasks,
    List<Task> allTasksForGrades,
  ) {
    final byCourse = <String, List<Task>>{};
    final now = DateTime.now();

    for (final task in tasks) {
      final name = _courseName(task);
      byCourse.putIfAbsent(name, () => []).add(task);
    }

    // Per-course grade averages come from every graded item (including grade
    // records that are excluded from the task metrics), keyed by course name.
    final gradeByCourse = _gradeByCourse(allTasksForGrades);

    final stats = byCourse.entries.map((entry) {
      final list = entry.value;
      final completed =
          list.where((t) => t.status == TaskStatus.completed).length;
      final missed = list.where((t) => _isMissed(t, now)).length;
      final pending = list
          .where(
            (t) =>
                t.status == TaskStatus.pending ||
                t.status == TaskStatus.inProgress,
          )
          .length;
      final urgentOrHigh = list
          .where(
            (t) =>
                t.priority == TaskPriority.urgent ||
                t.priority == TaskPriority.high,
          )
          .length;

      final grade = gradeByCourse[entry.key];

      return CourseProgressStat(
        courseName: entry.key,
        total: list.length,
        completed: completed,
        pending: pending,
        missed: missed,
        urgentOrHigh: urgentOrHigh,
        averageGradePct: grade?.$1,
        gradedCount: grade?.$2 ?? 0,
      );
    }).toList();

    stats.sort((a, b) {
      final riskA = _riskScore(a);
      final riskB = _riskScore(b);
      if (riskA != riskB) return riskB.compareTo(riskA);
      return b.total.compareTo(a.total);
    });

    return stats;
  }

  static int _riskScore(CourseProgressStat stat) {
    final incomplete = stat.pending + stat.missed;
    final completionPenalty = ((1.0 - stat.completionRate) * 100).round();
    return (stat.missed * 4) +
        (stat.pending * 2) +
        stat.urgentOrHigh +
        completionPenalty +
        incomplete;
  }

  static String _pickFocusCourse(List<CourseProgressStat> courseProgress) {
    if (courseProgress.isEmpty) return 'No courses yet';

    final withWork = courseProgress.firstWhere(
      (c) => (c.pending + c.missed) > 0,
      orElse: () => courseProgress.first,
    );

    return withWork.courseName;
  }

  static String _performanceLabel({
    required double completionRate,
    required int missedTasks,
    required int dueToday,
  }) {
    if (completionRate >= 0.85 && missedTasks == 0 && dueToday == 0) {
      return 'Excellent';
    }
    if (completionRate >= 0.65 && missedTasks <= 1) {
      return 'On Track';
    }
    if (completionRate >= 0.45) {
      return 'Needs Focus';
    }
    return 'At Risk';
  }

  static List<String> _buildSimpleInsights({
    required int totalTasks,
    required int completedTasks,
    required int pendingTasks,
    required int inProgressTasks,
    required int missedTasks,
    required int dueToday,
    required int upcoming48Hours,
    required double completionRate,
    required double completionRateChangePct,
    required double studyHoursThisRange,
    required double studyHoursChangePct,
    required double? averageGradePct,
    required String focusCourse,
  }) {
    final insights = <String>[];

    if (totalTasks == 0) {
      insights.add(
        'No assignments yet. Sync Google Classroom to start tracking your progress.',
      );
      return insights;
    }

    insights.add(
      'You finished $completedTasks of $totalTasks tasks (${(completionRate * 100).toStringAsFixed(0)}%).',
    );

    if (completionRateChangePct > 2) {
      insights.add(
        'Your completion trend is improving by ${completionRateChangePct.toStringAsFixed(1)}% compared with the previous period.',
      );
    } else if (completionRateChangePct < -2) {
      insights.add(
        'Your completion trend dropped by ${completionRateChangePct.abs().toStringAsFixed(1)}% compared with the previous period.',
      );
    } else {
      insights.add(
          'Your completion trend is steady compared with the previous period.');
    }

    if (studyHoursThisRange > 0) {
      final direction = studyHoursChangePct >= 0 ? 'up' : 'down';
      insights.add(
        'You studied for ${studyHoursThisRange.toStringAsFixed(1)}h this period ($direction ${studyHoursChangePct.abs().toStringAsFixed(1)}%).',
      );
    }

    if (missedTasks > 0) {
      insights.add(
        'You have $missedTasks missed task${missedTasks == 1 ? '' : 's'} to recover. Focus first on $focusCourse.',
      );
    } else if (pendingTasks > 0 || inProgressTasks > 0) {
      insights.add(
        'Great job keeping zero misses. You have $pendingTasks pending and $inProgressTasks in-progress task${(pendingTasks + inProgressTasks) == 1 ? '' : 's'} left.',
      );
    }

    if (dueToday > 0 || upcoming48Hours > 0) {
      insights.add(
        '$dueToday due today and $upcoming48Hours more within 48 hours. Plan short sessions now to stay ahead.',
      );
    }

    if (averageGradePct != null) {
      insights.add(
        'Your current average grade is ${averageGradePct.toStringAsFixed(1)}%.',
      );
    }

    return insights.take(5).toList();
  }

  static double _percentageChange(num current, num previous) {
    if (previous == 0) {
      return current == 0 ? 0.0 : 100.0;
    }
    return ((current - previous) / previous) * 100.0;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _completionDay(Task task) {
    final completion = task.completedAt ?? task.deadline;
    return _dateOnly(completion);
  }

  static bool _isMissed(Task task, DateTime now) {
    return task.hasRealDeadline &&
        task.deadline.isBefore(now) &&
        task.status != TaskStatus.completed;
  }

  static bool _countsAsTaskMetric(Task task) {
    if (task.itemType == 'actionable_task' ||
        task.itemType == 'completed_work') {
      return true;
    }
    if (task.source == 'manual') {
      return true;
    }
    return !task.isGradeRelated &&
        !task.isDashboardOnly &&
        task.itemType != 'grade_item' &&
        task.itemType != 'grade_bucket' &&
        task.itemType != 'material';
  }

  static String _courseName(Task task) {
    final name = task.courseName.trim();
    return name.isEmpty ? 'Other' : name;
  }

  static String? _normalizeSelectedCourse(String? selectedCourse) {
    if (selectedCourse == null) return null;
    final value = selectedCourse.trim();
    if (value.isEmpty) return null;
    return value;
  }
}
