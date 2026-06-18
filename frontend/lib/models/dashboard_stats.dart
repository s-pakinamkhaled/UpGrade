enum DashboardRange {
  last7Days,
  last14Days,
  last30Days,
}

extension DashboardRangeX on DashboardRange {
  int get days {
    switch (this) {
      case DashboardRange.last7Days:
        return 7;
      case DashboardRange.last14Days:
        return 14;
      case DashboardRange.last30Days:
        return 30;
    }
  }

  String get label {
    switch (this) {
      case DashboardRange.last7Days:
        return '7 days';
      case DashboardRange.last14Days:
        return '14 days';
      case DashboardRange.last30Days:
        return '30 days';
    }
  }
}

class DashboardDayPoint {
  final DateTime date;
  final int dueTasks;
  final int dueCompleted;
  final int duePending;
  final int dueMissed;
  final int completedTasks;
  final int completedMinutes;

  const DashboardDayPoint({
    required this.date,
    required this.dueTasks,
    required this.dueCompleted,
    required this.duePending,
    required this.dueMissed,
    required this.completedTasks,
    required this.completedMinutes,
  });
}

class CourseProgressStat {
  final String courseName;
  final int total;
  final int completed;
  final int pending;
  final int missed;
  final int urgentOrHigh;

  /// Average grade for this course as a percentage (0–100), or null if no
  /// graded items exist yet.
  final double? averageGradePct;

  /// How many graded items contributed to [averageGradePct].
  final int gradedCount;

  const CourseProgressStat({
    required this.courseName,
    required this.total,
    required this.completed,
    required this.pending,
    required this.missed,
    required this.urgentOrHigh,
    this.averageGradePct,
    this.gradedCount = 0,
  });

  double get completionRate => total == 0 ? 0.0 : completed / total;

  /// Combined academic risk for the course, factoring in both low grades and
  /// outstanding/missed work. Higher = more at risk.
  CourseRiskLevel get riskLevel {
    final grade = averageGradePct;
    // Grade-driven risk (dominant signal when grades exist).
    if (grade != null) {
      if (grade < 50 || missed >= 2) return CourseRiskLevel.high;
      if (grade < 65 || missed >= 1) return CourseRiskLevel.medium;
      if (grade < 75 && (pending + missed) > 0) return CourseRiskLevel.medium;
      return CourseRiskLevel.low;
    }
    // No grades yet → fall back to workload signals.
    if (missed >= 2) return CourseRiskLevel.high;
    if (missed >= 1 || urgentOrHigh >= 2) return CourseRiskLevel.medium;
    return CourseRiskLevel.low;
  }
}

enum CourseRiskLevel { low, medium, high }

extension CourseRiskLevelX on CourseRiskLevel {
  String get label {
    switch (this) {
      case CourseRiskLevel.low:
        return 'On track';
      case CourseRiskLevel.medium:
        return 'Caution';
      case CourseRiskLevel.high:
        return 'At risk';
    }
  }
}

class DashboardStats {
  final int totalTasks;
  final int completedTasks;
  final int pendingTasks;
  final int inProgressTasks;
  final int missedTasks;
  final int dueToday;
  final int upcoming48Hours;
  final int urgentOrHighTasks;
  final double completionRate;
  final double completionRateThisRange;
  final double completionRatePreviousRange;
  final double completionRateChangePct;
  final double studyHoursThisRange;
  final double studyHoursPreviousRange;
  final double studyHoursChangePct;
  final double? averageGradePct;
  final String performanceLabel;
  final bool isOnTrack;
  final String focusCourse;
  final String? selectedCourse;
  final DashboardRange range;
  final List<DashboardDayPoint> dailyPoints;
  final List<CourseProgressStat> courseProgress;
  final List<String> insights;

  const DashboardStats({
    required this.totalTasks,
    required this.completedTasks,
    required this.pendingTasks,
    required this.inProgressTasks,
    required this.missedTasks,
    required this.dueToday,
    required this.upcoming48Hours,
    required this.urgentOrHighTasks,
    required this.completionRate,
    required this.completionRateThisRange,
    required this.completionRatePreviousRange,
    required this.completionRateChangePct,
    required this.studyHoursThisRange,
    required this.studyHoursPreviousRange,
    required this.studyHoursChangePct,
    this.averageGradePct,
    required this.performanceLabel,
    required this.isOnTrack,
    required this.focusCourse,
    required this.selectedCourse,
    required this.range,
    required this.dailyPoints,
    required this.courseProgress,
    required this.insights,
  });
}
