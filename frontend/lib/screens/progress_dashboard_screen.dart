import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/dashboard_stats.dart';
import '../models/task.dart';
import '../providers/classroom_provider.dart';
import '../services/dashboard_metrics_service.dart';

class ProgressDashboardScreen extends StatefulWidget {
  final VoidCallback? openDrawer;
  final bool showAppBar;

  const ProgressDashboardScreen({
    super.key,
    this.openDrawer,
    this.showAppBar = true,
  });

  @override
  State<ProgressDashboardScreen> createState() =>
      _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  static const String _allCoursesLabel = 'All courses';

  DashboardRange _selectedRange = DashboardRange.last7Days;
  String _selectedCourse = _allCoursesLabel;

  @override
  Widget build(BuildContext context) {
    return Consumer<ClassroomProvider>(
      builder: (context, provider, _) {
        final allTasks = provider.tasks;
        final courses = _buildCourseOptions(allTasks);
        final effectiveCourse = courses.contains(_selectedCourse)
            ? _selectedCourse
            : _allCoursesLabel;
        final selectedCourseFilter =
            effectiveCourse == _allCoursesLabel ? null : effectiveCourse;

        final stats = DashboardMetricsService.build(
          tasks: allTasks,
          range: _selectedRange,
          selectedCourse: selectedCourseFilter,
        );

        final visibleTasks = selectedCourseFilter == null
            ? allTasks
            : allTasks
                .where((t) => _normalizedCourseName(t) == selectedCourseFilter)
                .toList();

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Scaffold(
          appBar: (widget.showAppBar && widget.openDrawer != null)
              ? _buildTopAppBar(context)
              : null,
          body: Container(
            color: isDark
                ? AppTheme.darkBackground
                : theme.scaffoldBackgroundColor,
            child: allTasks.isEmpty
                ? _buildEmptyState(context)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context, provider, stats, isDark),
                        const SizedBox(height: 18),
                        _buildFilters(
                            context, courses, effectiveCourse, isDark),
                        const SizedBox(height: 18),
                        _buildSummaryCards(context, stats, isDark),
                        const SizedBox(height: 18),
                        _buildProgressionCard(context, stats, isDark),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 760) {
                              return Column(
                                children: [
                                  _buildStudyHoursChart(
                                    context,
                                    stats,
                                    visibleTasks,
                                    isDark,
                                  ),
                                  const SizedBox(height: 18),
                                  _buildDailyOutcomeChart(
                                    context,
                                    stats,
                                    visibleTasks,
                                    isDark,
                                  ),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildStudyHoursChart(
                                    context,
                                    stats,
                                    visibleTasks,
                                    isDark,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: _buildDailyOutcomeChart(
                                    context,
                                    stats,
                                    visibleTasks,
                                    isDark,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        _buildCoursePerformanceChart(context, stats, isDark),
                        const SizedBox(height: 18),
                        _buildSimpleInsightsCard(context, stats, isDark),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  AppBar _buildTopAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: Icon(
          Navigator.canPop(context) ? Icons.arrow_back : Icons.menu,
        ),
        onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.maybePop(context);
          } else {
            widget.openDrawer?.call();
          }
        },
        tooltip: Navigator.canPop(context) ? 'Back' : 'Open menu',
      ),
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
              Icons.insights,
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
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ClassroomProvider provider,
    DashboardStats stats,
    bool isDark,
  ) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final secondary = isDark ? const Color(0xFF9CA3AF) : AppTheme.mediumGray;
    final statusColor = _statusColor(stats.performanceLabel);

    final syncedText = provider.syncedAt == null
        ? 'Not synced yet'
        : DateFormat('EEE, MMM d • h:mm a')
            .format(provider.syncedAt!.toLocal());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue.withOpacity(isDark ? 0.28 : 0.16),
            AppTheme.secondaryPurple.withOpacity(isDark ? 0.24 : 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Progress Dashboard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 9, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      stats.performanceLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Simple, real-time insights from your synced classroom data',
            style: TextStyle(
              color: secondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _headerChip(
                icon: Icons.update_rounded,
                text: 'Synced: $syncedText',
                isDark: isDark,
              ),
              _headerChip(
                icon: Icons.calendar_today_outlined,
                text: 'Window: ${_selectedRange.label}',
                isDark: isDark,
              ),
              _headerChip(
                icon: Icons.flag_outlined,
                text: 'Focus course: ${stats.focusCourse}',
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerChip({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.primaryBlue),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(
    BuildContext context,
    List<String> courses,
    String selectedCourse,
    bool isDark,
  ) {
    final surface = isDark
        ? const Color(0xFF1E1E1E)
        : Theme.of(context).colorScheme.surface;
    final secondary = isDark ? const Color(0xFF9CA3AF) : AppTheme.mediumGray;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 18, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'View Filters',
                style: TextStyle(
                  fontSize: 15,
                  color: secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DashboardRange.values.map((range) {
              final selected = _selectedRange == range;
              return ChoiceChip(
                selected: selected,
                label: Text(_rangeLabel(range)),
                labelStyle: TextStyle(
                  color: selected ? AppTheme.white : null,
                  fontWeight: FontWeight.w600,
                ),
                selectedColor: AppTheme.primaryBlue,
                backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                side: BorderSide(
                  color: selected
                      ? AppTheme.primaryBlue
                      : AppTheme.primaryBlue.withOpacity(0.2),
                ),
                onSelected: (value) {
                  if (!value) return;
                  setState(() {
                    _selectedRange = range;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedCourse,
            borderRadius: BorderRadius.circular(12),
            decoration: const InputDecoration(
              labelText: 'Course filter',
              prefixIcon: Icon(Icons.menu_book_outlined),
            ),
            items: courses
                .map(
                  (course) => DropdownMenuItem<String>(
                    value: course,
                    child: Text(course),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedCourse = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(
    BuildContext context,
    DashboardStats stats,
    bool isDark,
  ) {
    final cards = [
      _MetricCardData(
        title: 'Pending',
        value: '${stats.pendingTasks}',
        subtitle: 'not started yet',
        icon: Icons.pending_actions_rounded,
        color: AppTheme.warningOrange,
        progress:
            stats.totalTasks == 0 ? 0 : stats.pendingTasks / stats.totalTasks,
      ),
      _MetricCardData(
        title: 'In Progress',
        value: '${stats.inProgressTasks}',
        subtitle: 'currently being worked on',
        icon: Icons.autorenew_rounded,
        color: AppTheme.secondaryPurple,
        progress: stats.totalTasks == 0
            ? 0
            : stats.inProgressTasks / stats.totalTasks,
      ),
      _MetricCardData(
        title: 'Completed',
        value: '${stats.completedTasks}',
        subtitle: 'out of ${stats.totalTasks} total tasks',
        icon: Icons.check_circle_rounded,
        color: AppTheme.successGreen,
        progress: stats.completionRate,
      ),
      _MetricCardData(
        title: 'Missed',
        value: '${stats.missedTasks}',
        subtitle: stats.missedTasks == 0
            ? 'Excellent, no missed tasks'
            : 'Time to recover these tasks',
        icon: Icons.error_outline_rounded,
        color: AppTheme.errorRed,
        progress:
            stats.totalTasks == 0 ? 0 : stats.missedTasks / stats.totalTasks,
      ),
      _MetricCardData(
        title: 'Completion Rate',
        value: '${(stats.completionRate * 100).toStringAsFixed(0)}%',
        subtitle: '${stats.completedTasks}/${stats.totalTasks} tasks completed',
        icon: Icons.percent_rounded,
        color: AppTheme.primaryBlue,
        progress: stats.completionRate,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            children: cards
                .map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildMetricCard(context, card, isDark),
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: cards
              .asMap()
              .entries
              .map(
                (entry) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: entry.key == cards.length - 1 ? 0 : 12),
                    child: _buildMetricCard(context, entry.value, isDark),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    _MetricCardData data,
    bool isDark,
  ) {
    final surface = isDark
        ? const Color(0xFF1E1E1E)
        : Theme.of(context).colorScheme.surface;
    final secondary = isDark ? const Color(0xFF9CA3AF) : AppTheme.mediumGray;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: data.color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: data.color, size: 18),
              ),
              const Spacer(),
              Text(
                data.title,
                style: TextStyle(
                  color: secondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.subtitle,
            style: TextStyle(
              color: secondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: data.progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: secondary.withOpacity(0.24),
              valueColor: AlwaysStoppedAnimation<Color>(data.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressionCard(
    BuildContext context,
    DashboardStats stats,
    bool isDark,
  ) {
    final surface = isDark
        ? const Color(0xFF1E1E1E)
        : Theme.of(context).colorScheme.surface;
    final secondary = isDark ? const Color(0xFF9CA3AF) : AppTheme.mediumGray;

    final total = math.max(stats.totalTasks, 1);
    final completedPart = stats.completedTasks / total;
    final pendingPart = stats.pendingTasks / total;
    final missedPart = stats.missedTasks / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.secondaryPurple.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryPurple.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.timeline,
                  color: AppTheme.secondaryPurple,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Your Progression',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(
                    flex: (completedPart * 1000).round().clamp(1, 1000),
                    child: Container(color: AppTheme.successGreen),
                  ),
                  Expanded(
                    flex: (pendingPart * 1000).round().clamp(1, 1000),
                    child: Container(color: AppTheme.warningOrange),
                  ),
                  Expanded(
                    flex: (missedPart * 1000).round().clamp(1, 1000),
                    child: Container(color: AppTheme.errorRed),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _progressLegend(
                color: AppTheme.successGreen,
                text: 'Finished ${stats.completedTasks}',
                secondary: secondary,
              ),
              _progressLegend(
                color: AppTheme.warningOrange,
                text: 'Pending ${stats.pendingTasks}',
                secondary: secondary,
              ),
              _progressLegend(
                color: AppTheme.errorRed,
                text: 'Missed ${stats.missedTasks}',
                secondary: secondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            stats.totalTasks == 0
                ? 'No tasks available yet. Sync data to unlock progression insights.'
                : 'You are at ${(stats.completionRate * 100).toStringAsFixed(0)}% completion. '
                    'Complete ${_tasksNeededForTarget(stats, 80)} more task(s) to reach 80%.',
            style: TextStyle(
              color: secondary,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressLegend({
    required Color color,
    required String text,
    required Color secondary,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: secondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStudyHoursChart(
    BuildContext context,
    DashboardStats stats,
    List<Task> visibleTasks,
    bool isDark,
  ) {
    final surface = isDark
        ? const Color(0xFF1E1E1E)
        : Theme.of(context).colorScheme.surface;
    final secondary = isDark ? const Color(0xFF9CA3AF) : AppTheme.mediumGray;

    final hours = stats.dailyPoints
        .map((p) => p.completedMinutes / 60.0)
        .toList(growable: false);
    final maxHour =
        hours.isEmpty ? 1.0 : math.max(1.0, hours.reduce(math.max) + 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Study Hours Trend',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${stats.studyHoursThisRange.toStringAsFixed(1)}h total',
                style: TextStyle(
                  color: secondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 230,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (stats.dailyPoints.length - 1).toDouble(),
                minY: 0,
                maxY: maxHour,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: secondary.withOpacity(0.16),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(0),
                        style: TextStyle(fontSize: 11, color: secondary),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= stats.dailyPoints.length) {
                          return const SizedBox.shrink();
                        }
                        if (_hideDenseLabel(index, stats.dailyPoints.length)) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _dayLabel(stats.dailyPoints[index].date,
                                compact: true),
                            style: TextStyle(fontSize: 11, color: secondary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: AppTheme.primaryBlue.withOpacity(0.92),
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final index = spot.x.toInt();
                        final point = stats.dailyPoints[index];
                        return LineTooltipItem(
                          '${DateFormat('EEE, MMM d').format(point.date)}\n'
                          '${spot.y.toStringAsFixed(1)}h completed',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  touchCallback: (event, response) {
                    if (event is! FlTapUpEvent) return;
                    final spots = response?.lineBarSpots;
                    if (spots == null || spots.isEmpty) return;
                    final index = spots.first.x.toInt();
                    final point = stats.dailyPoints[index];
                    _showDayBreakdown(
                      context: context,
                      point: point,
                      visibleTasks: visibleTasks,
                    );
                  },
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: hours
                        .asMap()
                        .entries
                        .map((entry) =>
                            FlSpot(entry.key.toDouble(), entry.value))
                        .toList(),
                    isCurved: true,
                    color: AppTheme.primaryBlue,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primaryBlue.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyOutcomeChart(
    BuildContext context,
    DashboardStats stats,
    List<Task> visibleTasks,
    bool isDark,
  ) {
    final surface = isDark
        ? const Color(0xFF1E1E1E)
        : Theme.of(context).colorScheme.surface;
    final secondary = isDark ? const Color(0xFF9CA3AF) : AppTheme.mediumGray;

    final maxDue = stats.dailyPoints.isEmpty
        ? 1.0
        : math.max(
            1.0,
            stats.dailyPoints
                    .map((p) => p.dueTasks)
                    .reduce(math.max)
                    .toDouble() +
                1.0,
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.secondaryPurple.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: AppTheme.secondaryPurple),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Daily Outcome Breakdown',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 230,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxDue,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: secondary.withOpacity(0.16),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(0),
                        style: TextStyle(fontSize: 11, color: secondary),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= stats.dailyPoints.length) {
                          return const SizedBox.shrink();
                        }
                        if (_hideDenseLabel(index, stats.dailyPoints.length)) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _dayLabel(stats.dailyPoints[index].date,
                                compact: true),
                            style: TextStyle(fontSize: 11, color: secondary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: AppTheme.secondaryPurple.withOpacity(0.92),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final point = stats.dailyPoints[group.x.toInt()];
                      return BarTooltipItem(
                        '${DateFormat('EEE, MMM d').format(point.date)}\n'
                        'Done: ${point.dueCompleted}\n'
                        'Pending: ${point.duePending}\n'
                        'Missed: ${point.dueMissed}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                  touchCallback: (event, response) {
                    if (event is! FlTapUpEvent) return;
                    final spot = response?.spot;
                    if (spot == null) return;
                    final index = spot.touchedBarGroupIndex;
                    if (index < 0 || index >= stats.dailyPoints.length) return;
                    _showDayBreakdown(
                      context: context,
                      point: stats.dailyPoints[index],
                      visibleTasks: visibleTasks,
                    );
                  },
                ),
                barGroups: stats.dailyPoints.asMap().entries.map((entry) {
                  final point = entry.value;
                  final completed = point.dueCompleted.toDouble();
                  final pending = point.duePending.toDouble();
                  final missed = point.dueMissed.toDouble();
                  final total = (completed + pending + missed);

                  if (total == 0) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: 0.05,
                          width: 16,
                          color: secondary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    );
                  }

                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: total,
                        width: 16,
                        borderRadius: BorderRadius.circular(6),
                        color: secondary.withOpacity(0.15),
                        rodStackItems: [
                          BarChartRodStackItem(
                              0, completed, AppTheme.successGreen),
                          BarChartRodStackItem(
                            completed,
                            completed + pending,
                            AppTheme.warningOrange,
                          ),
                          BarChartRodStackItem(
                            completed + pending,
                            total,
                            AppTheme.errorRed,
                          ),
                        ],
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _progressLegend(
                color: AppTheme.successGreen,
                text: 'Finished',
                secondary: secondary,
              ),
              _progressLegend(
                color: AppTheme.warningOrange,
                text: 'Pending',
                secondary: secondary,
              ),
              _progressLegend(
                color: AppTheme.errorRed,
                text: 'Missed',
                secondary: secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoursePerformanceChart(
    BuildContext context,
    DashboardStats stats,
    bool isDark,
  ) {
    final surface = isDark
        ? const Color(0xFF1E1E1E)
        : Theme.of(context).colorScheme.surface;
    final secondary = isDark ? const Color(0xFF9CA3AF) : AppTheme.mediumGray;

    final courseStats = stats.courseProgress.take(8).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.successGreen.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_outlined, color: AppTheme.successGreen),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Course Completion',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              if (_selectedCourse != _allCoursesLabel)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedCourse = _allCoursesLabel;
                    });
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear filter'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 240,
            child: courseStats.isEmpty
                ? Center(
                    child: Text(
                      'No course data available',
                      style: TextStyle(color: secondary),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 100,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: secondary.withOpacity(0.16),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) => Text(
                              '${value.toStringAsFixed(0)}%',
                              style: TextStyle(fontSize: 11, color: secondary),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 38,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= courseStats.length) {
                                return const SizedBox.shrink();
                              }
                              final name = courseStats[index].courseName;
                              final short = name.length > 10
                                  ? '${name.substring(0, 10)}..'
                                  : name;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  short,
                                  style:
                                      TextStyle(fontSize: 11, color: secondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        enabled: true,
                        handleBuiltInTouches: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBgColor:
                              AppTheme.successGreen.withOpacity(0.92),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final course = courseStats[group.x.toInt()];
                            return BarTooltipItem(
                              '${course.courseName}\n'
                              'Completion: ${(course.completionRate * 100).toStringAsFixed(0)}%\n'
                              'Done ${course.completed}/${course.total}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                        touchCallback: (event, response) {
                          if (event is! FlTapUpEvent) return;
                          final spot = response?.spot;
                          if (spot == null) return;
                          final index = spot.touchedBarGroupIndex;
                          if (index < 0 || index >= courseStats.length) return;
                          setState(() {
                            _selectedCourse = courseStats[index].courseName;
                          });
                        },
                      ),
                      barGroups: courseStats.asMap().entries.map((entry) {
                        final course = entry.value;
                        final selected = _selectedCourse == course.courseName;
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: (course.completionRate * 100).clamp(0, 100),
                              width: 18,
                              color: selected
                                  ? AppTheme.primaryBlue
                                  : AppTheme.successGreen,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleInsightsCard(
    BuildContext context,
    DashboardStats stats,
    bool isDark,
  ) {
    final surface = isDark
        ? const Color(0xFF1E1E1E)
        : Theme.of(context).colorScheme.surface;
    final secondary = isDark ? const Color(0xFF9CA3AF) : AppTheme.mediumGray;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warningOrange.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppTheme.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Simple Insights',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...stats.insights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.bolt,
                      color: AppTheme.warningOrange,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight,
                      style: TextStyle(
                        fontSize: 13,
                        color: secondary,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (stats.averageGradePct != null) ...[
            const SizedBox(height: 6),
            Text(
              'Average grade: ${stats.averageGradePct!.toStringAsFixed(1)}%',
              style: TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark ? const Color(0xFF9CA3AF) : AppTheme.mediumGray;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.softGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.analytics_outlined,
                size: 48,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No student data yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Sync Google Classroom or add manual courses to unlock interactive insights.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: secondary),
            ),
          ],
        ),
      ),
    );
  }

  void _showDayBreakdown({
    required BuildContext context,
    required DashboardDayPoint point,
    required List<Task> visibleTasks,
  }) {
    final day = _dateOnly(point.date);

    final dueTasks = visibleTasks
        .where((task) => _dateOnly(task.deadline) == day)
        .toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));

    final completedOnDay = visibleTasks
        .where((task) => task.status == TaskStatus.completed)
        .where((task) => _completionDate(task) == day)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final secondary = Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF9CA3AF)
            : AppTheme.mediumGray;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 18,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: AppTheme.primaryBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DateFormat('EEEE, MMM d').format(day),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _sheetStatChip(
                        label: 'Done',
                        value: '${point.dueCompleted}',
                        color: AppTheme.successGreen,
                      ),
                      _sheetStatChip(
                        label: 'Pending',
                        value: '${point.duePending}',
                        color: AppTheme.warningOrange,
                      ),
                      _sheetStatChip(
                        label: 'Missed',
                        value: '${point.dueMissed}',
                        color: AppTheme.errorRed,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _taskSection(
                    title: 'Tasks due this day',
                    tasks: dueTasks,
                    empty: 'No tasks due on this day.',
                    secondary: secondary,
                  ),
                  const SizedBox(height: 14),
                  _taskSection(
                    title: 'Tasks completed this day',
                    tasks: completedOnDay,
                    empty: 'No completions recorded on this day.',
                    secondary: secondary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sheetStatChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _taskSection({
    required String title,
    required List<Task> tasks,
    required String empty,
    required Color secondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (tasks.isEmpty)
          Text(
            empty,
            style: TextStyle(color: secondary, fontSize: 13),
          )
        else
          ...tasks.take(8).map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withOpacity(0.16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_normalizedCourseName(task)} • ${_taskStatusLabel(task)}',
                          style: TextStyle(
                            color: secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  List<String> _buildCourseOptions(List<Task> tasks) {
    final names = tasks.map(_normalizedCourseName).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [_allCoursesLabel, ...names];
  }

  String _normalizedCourseName(Task task) {
    final name = task.courseName.trim();
    return name.isEmpty ? 'Other' : name;
  }

  String _taskStatusLabel(Task task) {
    switch (task.status) {
      case TaskStatus.completed:
        return 'Finished';
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.inProgress:
        return 'In progress';
      case TaskStatus.missed:
        return 'Missed';
    }
  }

  bool _hideDenseLabel(int index, int total) {
    if (total > 20) {
      return index % 5 != 0 && index != total - 1;
    }
    if (total > 10) {
      return index % 2 != 0 && index != total - 1;
    }
    return false;
  }

  String _dayLabel(DateTime date, {required bool compact}) {
    return compact
        ? DateFormat('E').format(date)
        : DateFormat('EEE, MMM d').format(date);
  }

  String _rangeLabel(DashboardRange range) {
    switch (range) {
      case DashboardRange.last7Days:
        return 'Last 7 days';
      case DashboardRange.last14Days:
        return 'Last 14 days';
      case DashboardRange.last30Days:
        return 'Last 30 days';
    }
  }

  String _signed(double value) {
    final sign = value >= 0 ? '+' : '-';
    return '$sign${value.abs().toStringAsFixed(1)}%';
  }

  int _tasksNeededForTarget(DashboardStats stats, int targetPercent) {
    final total = stats.totalTasks;
    if (total == 0) return 0;
    final targetDone = ((targetPercent / 100) * total).ceil();
    final need = targetDone - stats.completedTasks;
    return need > 0 ? need : 0;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _completionDate(Task task) {
    final completion = task.completedAt ?? task.deadline;
    return _dateOnly(completion);
  }

  Color _statusColor(String label) {
    switch (label) {
      case 'Excellent':
        return AppTheme.successGreen;
      case 'On Track':
        return AppTheme.primaryBlue;
      case 'Needs Focus':
        return AppTheme.warningOrange;
      case 'At Risk':
        return AppTheme.errorRed;
      default:
        return AppTheme.mediumGray;
    }
  }
}

class _MetricCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double progress;

  const _MetricCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.progress,
  });
}
