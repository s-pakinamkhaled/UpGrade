import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/task.dart';
import '../providers/classroom_provider.dart';
import '../widgets/gradient_card.dart';

class ProgressDashboardScreen extends StatelessWidget {
  final VoidCallback? openDrawer;

  const ProgressDashboardScreen({super.key, this.openDrawer});

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    return Consumer<ClassroomProvider>(
      builder: (context, provider, _) {
        final tasks = provider.tasks;
        final stats = _computeStats(tasks);
        final courseStats = _computeCourseStats(tasks);
        final last7Days = _computeLast7DaysTrend(tasks);

        return Scaffold(
          appBar: AppBar(
            leading: openDrawer != null
                ? IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: openDrawer,
                    tooltip: 'Open menu',
                  )
                : null,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: AppTheme.softGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.dashboard,
                    size: 18,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Progress Dashboard',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          body: tasks.isEmpty
              ? _buildEmptyState(context)
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCard(stats),
                        const SizedBox(height: 16),
                        _buildStatsGrid(stats),
                        const SizedBox(height: 24),
                        if (last7Days.isNotEmpty)
                          _buildTrendChart(last7Days),
                        if (last7Days.isNotEmpty) const SizedBox(height: 16),
                        if (courseStats.isNotEmpty)
                          _buildCourseChart(courseStats),
                        if (courseStats.isNotEmpty) const SizedBox(height: 16),
                        _buildAISummary(stats, courseStats),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: AppTheme.primaryBlue.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No assignment data yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sync Google Classroom or add courses in onboarding to see your progress here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.mediumGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(_Stats stats) {
    final rate = stats.total == 0 ? 0.0 : stats.completed / stats.total;
    return GradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assignment progress',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            stats.total == 0
                ? 'No assignments yet'
                : '${(rate * 100).toInt()}% of assignments completed (${stats.completed} of ${stats.total})',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.darkText.withOpacity(0.7),
            ),
          ),
          if (stats.total > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: rate,
                backgroundColor: AppTheme.lightGray,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                minHeight: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsGrid(_Stats stats) {
    final completedTotal = stats.total == 0 ? '0/0' : '${stats.completed}/${stats.total}';
    final estMinutes = stats.estimatedMinutesCompleted;
    final estDisplay = estMinutes >= 60
        ? '${(estMinutes / 60).toStringAsFixed(1)}h'
        : '${estMinutes}m';
    final productivity = stats.total == 0
        ? '—'
        : '${(stats.completionRate * 10).toStringAsFixed(1)}/10';
    final onTime = stats.pastDueTotal == 0
        ? '—'
        : '${stats.pastDueCompleted}/${stats.pastDueTotal}';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Completed',
                completedTotal,
                Icons.check_circle,
                AppTheme.successGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Est. study (done)',
                estDisplay,
                Icons.timer,
                AppTheme.primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Completion score',
                productivity,
                Icons.trending_up,
                AppTheme.secondaryPurple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'On-time (past due)',
                onTime,
                Icons.schedule,
                AppTheme.warningOrange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrendChart(List<_DayPoint> last7Days) {
    final maxCompleted = last7Days.map((e) => e.completed).reduce((a, b) => a > b ? a : b);
    final maxTotal = last7Days.map((e) => e.total).reduce((a, b) => a > b ? a : b);
    final maxVal = (maxCompleted > maxTotal ? maxCompleted : maxTotal);
    final maxY = (maxVal > 0 ? maxVal : 1).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tasks due & completed (last 7 days)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= 0 && i < last7Days.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                last7Days[i].label,
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: last7Days
                          .asMap()
                          .entries
                          .map((e) => FlSpot(e.key.toDouble(), e.value.completed.toDouble()))
                          .toList(),
                      isCurved: true,
                      color: AppTheme.successGreen,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.successGreen.withOpacity(0.15),
                      ),
                    ),
                    LineChartBarData(
                      spots: last7Days
                          .asMap()
                          .entries
                          .map((e) => FlSpot(e.key.toDouble(), e.value.total.toDouble()))
                          .toList(),
                      isCurved: true,
                      color: AppTheme.primaryBlue,
                      barWidth: 2,
                      dotData: FlDotData(show: true),
                      dashArray: [4, 2],
                    ),
                  ],
                  minX: 0,
                  maxX: (last7Days.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: AppTheme.successGreen),
                const SizedBox(width: 6),
                const Text('Completed', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                Icon(Icons.circle, size: 10, color: AppTheme.primaryBlue),
                const SizedBox(width: 6),
                const Text('Due', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseChart(List<_CourseStat> courseStats) {
    final maxY = courseStats
        .map((e) => e.total)
        .reduce((a, b) => a > b ? a : b);
    final maxVal = (maxY > 0 ? maxY : 1).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Task completion by course',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= 0 && i < courseStats.length) {
                            final name = courseStats[i].courseName;
                            final short = name.length > 8 ? '${name.substring(0, 8)}.' : name;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                short,
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: courseStats.asMap().entries.map((entry) {
                    final i = entry.key;
                    final s = entry.value;
                    final colors = [
                      AppTheme.primaryBlue,
                      AppTheme.secondaryPurple,
                      AppTheme.warningOrange,
                      AppTheme.successGreen,
                      AppTheme.mediumGray,
                    ];
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: s.completed.toDouble(),
                          color: colors[i % colors.length],
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                      showingTooltipIndicators: [0],
                    );
                  }).toList(),
                ),
              ),
            ),
            if (courseStats.length <= 5)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: courseStats.asMap().entries.map((e) {
                    final name = e.value.courseName;
                    final short = name.length > 12 ? '${name.substring(0, 12)}.' : name;
                    return Chip(
                      label: Text('$short: ${e.value.completed}/${e.value.total}', style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAISummary(_Stats stats, List<_CourseStat> courseStats) {
    String text;
    if (stats.total == 0) {
      text = 'Add or sync assignments to see your progress and tips here.';
    } else {
      final pct = (stats.completionRate * 100).toInt();
      final missed = stats.missed;
      final gradePart = stats.averageGrade != null
          ? ' Your average grade on graded work is ${stats.averageGrade!.toStringAsFixed(1)}%.'
          : '';
      if (missed > 0) {
        text = 'You\'ve completed $pct% of your assignments ($stats.completed of ${stats.total}).'
            ' You have $missed missed assignment${missed == 1 ? '' : 's'}.'
            '$gradePart Check the Past Tasks screen to plan catch-up.';
      } else {
        text = 'You\'ve completed $pct% of your assignments ($stats.completed of ${stats.total}).'
            '$gradePart Keep it up!';
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppTheme.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.darkText.withOpacity(0.8),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.08),
              color.withOpacity(0.03),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.darkText.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static _Stats _computeStats(List<Task> tasks) {
    final total = tasks.length;
    final completed = tasks.where((t) => t.status == TaskStatus.completed).length;
    final missed = tasks.where((t) => t.status == TaskStatus.missed).length;
    final now = DateTime.now();
    final today = _dateOnly(now);
    final pastDue = tasks.where((t) => _dateOnly(t.deadline).isBefore(today)).toList();
    final pastDueTotal = pastDue.length;
    final pastDueCompleted = pastDue.where((t) => t.status == TaskStatus.completed).length;
    final estimatedMinutesCompleted = tasks
        .where((t) => t.status == TaskStatus.completed)
        .fold<int>(0, (sum, t) => sum + t.estimatedMinutes);

    double? averageGrade;
    final graded = tasks.where((t) => t.assignedGrade != null && t.maxPoints != null && t.maxPoints! > 0).toList();
    if (graded.isNotEmpty) {
      var sum = 0.0;
      for (final t in graded) {
        sum += (t.assignedGrade! / t.maxPoints!) * 100;
      }
      averageGrade = sum / graded.length;
    }

    return _Stats(
      total: total,
      completed: completed,
      missed: missed,
      completionRate: total == 0 ? 0.0 : completed / total,
      estimatedMinutesCompleted: estimatedMinutesCompleted,
      pastDueTotal: pastDueTotal,
      pastDueCompleted: pastDueCompleted,
      averageGrade: averageGrade,
    );
  }

  static List<_CourseStat> _computeCourseStats(List<Task> tasks) {
    final byCourse = <String, List<Task>>{};
    for (final t in tasks) {
      final name = t.courseName.isEmpty ? 'Other' : t.courseName;
      byCourse.putIfAbsent(name, () => []).add(t);
    }
    return byCourse.entries.map((e) {
      final list = e.value;
      final completed = list.where((t) => t.status == TaskStatus.completed).length;
      return _CourseStat(
        courseName: e.key,
        total: list.length,
        completed: completed,
      );
    }).where((s) => s.total > 0).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  static List<_DayPoint> _computeLast7DaysTrend(List<Task> tasks) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final points = <_DayPoint>[];
    for (var i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dayTasks = tasks.where((t) => _dateOnly(t.deadline) == date).toList();
      final total = dayTasks.length;
      final completed = dayTasks.where((t) => t.status == TaskStatus.completed).length;
      String label;
      if (i == 0) {
        label = 'Today';
      } else if (i == 1) {
        label = 'Yest.';
      } else {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        label = days[date.weekday - 1];
      }
      points.add(_DayPoint(label: label, total: total, completed: completed));
    }
    return points;
  }
}

class _Stats {
  final int total;
  final int completed;
  final int missed;
  final double completionRate;
  final int estimatedMinutesCompleted;
  final int pastDueTotal;
  final int pastDueCompleted;
  final double? averageGrade;

  _Stats({
    required this.total,
    required this.completed,
    required this.missed,
    required this.completionRate,
    required this.estimatedMinutesCompleted,
    required this.pastDueTotal,
    required this.pastDueCompleted,
    this.averageGrade,
  });
}

class _CourseStat {
  final String courseName;
  final int total;
  final int completed;

  _CourseStat({
    required this.courseName,
    required this.total,
    required this.completed,
  });
}

class _DayPoint {
  final String label;
  final int total;
  final int completed;

  _DayPoint({
    required this.label,
    required this.total,
    required this.completed,
  });
}
