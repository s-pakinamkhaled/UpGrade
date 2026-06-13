import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/dashboard_shell_navigation.dart';
import '../core/theme.dart';
import '../models/task.dart';
import '../providers/classroom_provider.dart';
import '../widgets/dashboard_secondary_shell.dart';
import '../widgets/upgrade_visual_system.dart';

/// Warnings derived from synced / manual tasks only (no mock alerts).
class WarningsScreen extends StatefulWidget {
  const WarningsScreen({super.key});

  @override
  State<WarningsScreen> createState() => _WarningsScreenState();
}

class _WarningsScreenState extends State<WarningsScreen> {
  static const String _kDismissPrefsKey = 'upgrade_warning_dismissals_v1';

  static const Color _criticalBg = Color(0xFFFFF1F2);
  static const Color _criticalFg = Color(0xFFEF4444);
  static const Color _highBg = Color(0xFFFFF7ED);
  static const Color _highFg = Color(0xFFF97316);
  static const Color _resolvedBg = Color(0xFFF0FDF4);
  static const Color _resolvedFg = Color(0xFF22C55E);
  static const Color _mediumBg = Color(0xFFEFF6FF);
  static const Color _mediumFg = Color(0xFF3B82F6);
  static const Color _borderLight = Color(0xFFE2E8F0);

  Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dismissed = p.getStringList(_kDismissPrefsKey)?.toSet() ?? {};
    });
  }

  Future<void> _persistDismissed() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kDismissPrefsKey, _dismissed.toList());
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _deadlineIsToday(Task t) {
    if (!t.hasRealDeadline) return false;
    final d = _dateOnly(t.deadline);
    final n = _dateOnly(DateTime.now());
    return d == n;
  }

  static String _formatPast(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays >= 1) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inMinutes >= 1) {
      return '${diff.inMinutes} min ago';
    }
    return 'Just now';
  }

  static String _formatUntil(DateTime deadline) {
    final diff = deadline.difference(DateTime.now());
    if (diff.isNegative) return 'now';
    if (diff.inMinutes < 60) {
      return 'in ${diff.inMinutes} min';
    }
    if (diff.inHours < 48) {
      return 'in ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'}';
    }
    return 'in ${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
  }

  static final _deadlineFmt = DateFormat('MMM d, yyyy · h:mm a');

  int _resolvedTodayCount(List<Task> tasks) {
    final n = _dateOnly(DateTime.now());
    return tasks.where((t) {
      final c = t.completedAt;
      if (c == null) return false;
      return _dateOnly(c) == n;
    }).length;
  }

  /// Overdue / missed → urgent. Due within 48h → high. Heavy today → one medium card.
  List<Warning> _warningsFromTasks(List<Task> tasks) {
    final now = DateTime.now();
    final dismissed = _dismissed;
    final out = <Warning>[];

    final open = tasks.where((t) => t.status != TaskStatus.completed).toList();

    for (final t in open) {
      final overdue =
          t.hasRealDeadline && (t.status == TaskStatus.missed || t.isOverdue);
      if (!overdue) continue;
      final id = 'overdue_${t.id}';
      if (dismissed.contains(id)) continue;

      final course = t.courseName.isNotEmpty ? t.courseName : t.courseId;
      out.add(
        Warning(
          id: id,
          task: t,
          type: WarningType.missedTask,
          title: 'Overdue: ${t.title}',
          message:
              'Deadline was ${_deadlineFmt.format(t.deadline)} (${_formatPast(t.deadline)}).',
          severity: WarningSeverity.urgent,
          action: 'Open task',
          category: course,
          timeAgo: _formatPast(t.deadline),
        ),
      );
    }

    for (final t in open) {
      if (t.status == TaskStatus.missed || t.isOverdue) continue;
      if (!t.hasRealDeadline) continue;
      if (t.deadline.isBefore(now)) continue;
      final hours = t.deadline.difference(now).inHours;
      if (hours > 48) continue;
      final id = 'dueSoon_${t.id}';
      if (dismissed.contains(id)) continue;

      final course = t.courseName.isNotEmpty ? t.courseName : t.courseId;
      out.add(
        Warning(
          id: id,
          task: t,
          type: WarningType.deadline,
          title: 'Due soon: ${t.title}',
          message:
              'Deadline ${_deadlineFmt.format(t.deadline)} (${_formatUntil(t.deadline)}).',
          severity: WarningSeverity.high,
          action: 'Open task',
          category: course,
          timeAgo: _formatUntil(t.deadline),
        ),
      );
    }

    final dueTodayCount = open
        .where(
          (t) =>
              t.status != TaskStatus.missed &&
              !t.isOverdue &&
              _deadlineIsToday(t),
        )
        .length;
    final workloadId = 'workload_${now.year}_${now.month}_${now.day}';
    if (dueTodayCount >= 6 && !dismissed.contains(workloadId)) {
      out.add(
        Warning(
          id: workloadId,
          task: null,
          type: WarningType.workload,
          title: 'Heavy workload today',
          message:
              'You have $dueTodayCount open tasks due today. Consider prioritizing or rescheduling.',
          severity: WarningSeverity.medium,
          action: 'View My Tasks',
          category: 'Multiple',
          timeAgo: 'Today',
        ),
      );
    }

    int sevRank(WarningSeverity s) {
      switch (s) {
        case WarningSeverity.urgent:
          return 0;
        case WarningSeverity.high:
          return 1;
        case WarningSeverity.medium:
          return 2;
        case WarningSeverity.low:
          return 3;
      }
    }

    out.sort((a, b) {
      final c = sevRank(a.severity).compareTo(sevRank(b.severity));
      if (c != 0) return c;
      return a.title.compareTo(b.title);
    });
    return out;
  }

  void _dismiss(Warning warning) {
    setState(() => _dismissed.add(warning.id));
    _persistDismissed();
  }

  void _onTakeAction(BuildContext context, Warning w) {
    if (w.task != null) {
      Navigator.of(context).pushNamed(
        AppConstants.routeTaskExecution,
        arguments: w.task,
      );
    } else {
      selectMainShellRoute(context, AppConstants.routeDailyPlanner);
    }
  }

  Widget _buildMainContent(
    BuildContext context,
    List<Task> tasks,
    Color surface,
    Color onSurface,
    Color secondary,
    UpGradeRem rem,
  ) {
    final warnings = _warningsFromTasks(tasks);
    final criticalCount =
        warnings.where((w) => w.severity == WarningSeverity.urgent).length;
    final highCount =
        warnings.where((w) => w.severity == WarningSeverity.high).length;
    final resolvedToday = _resolvedTodayCount(tasks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, secondary, rem),
        const SizedBox(height: 28),
        _buildSummaryRow(
          context,
          surface,
          onSurface,
          criticalCount: criticalCount,
          highCount: highCount,
          resolvedToday: resolvedToday,
        ),
        const SizedBox(height: 28),
        Text(
          'Active Warnings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 16),
        if (warnings.isEmpty)
          _buildEmptyState(secondary)
        else
          ...warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildAlertCard(
                context,
                warning: w,
                onSurface: onSurface,
                secondary: secondary,
                onTakeAction: () => _onTakeAction(context, w),
                onDismiss: () => _dismiss(w),
              ),
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final secondary = isDark ? const Color(0xFF9CA3AF) : AppTheme.mediumGray;
    final tasks = context.watch<ClassroomProvider>().tasks;

    Widget page(double width) {
      final rem = UpGradeRem(width);
      return DecoratedBox(
        decoration: UpGradePageDecor.pageBackground(isDark),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _buildMainContent(
            context,
            tasks,
            surface,
            onSurface,
            secondary,
            rem,
          ),
        ),
      );
    }

    final narrow = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, c) => page(c.maxWidth),
      ),
    );

    return DashboardSecondaryShell(
      narrow: narrow,
      wideBody: LayoutBuilder(
        builder: (context, c) => page(c.maxWidth),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color secondary,
    UpGradeRem rem,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UpGradeGradientTitle(
          'Warnings & Alerts',
          rem: rem,
          isDark: isDark,
        ),
        SizedBox(height: rem.space(0.4)),
        Text(
          'Based on your courses and deadlines',
          style: TextStyle(
            fontSize: rem.pageSubtitle,
            color: secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    Color surface,
    Color onSurface, {
    required int criticalCount,
    required int highCount,
    required int resolvedToday,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        if (isNarrow) {
          return Column(
            children: [
              _summaryCard(
                context,
                icon: Icons.warning_amber_rounded,
                label: 'Critical',
                value: '$criticalCount',
                bg: isDark ? _criticalFg.withOpacity(0.18) : _criticalBg,
                fg: _criticalFg,
                surface: surface,
              ),
              const SizedBox(height: 12),
              _summaryCard(
                context,
                icon: Icons.error_outline,
                label: 'High Priority',
                value: '$highCount',
                bg: isDark ? _highFg.withOpacity(0.18) : _highBg,
                fg: _highFg,
                surface: surface,
              ),
              const SizedBox(height: 12),
              _summaryCard(
                context,
                icon: Icons.check_circle_outline,
                label: 'Resolved Today',
                value: '$resolvedToday',
                bg: isDark ? _resolvedFg.withOpacity(0.18) : _resolvedBg,
                fg: _resolvedFg,
                surface: surface,
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: _summaryCard(
                context,
                icon: Icons.warning_amber_rounded,
                label: 'Critical',
                value: '$criticalCount',
                bg: isDark ? _criticalFg.withOpacity(0.18) : _criticalBg,
                fg: _criticalFg,
                surface: surface,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _summaryCard(
                context,
                icon: Icons.error_outline,
                label: 'High Priority',
                value: '$highCount',
                bg: isDark ? _highFg.withOpacity(0.18) : _highBg,
                fg: _highFg,
                surface: surface,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _summaryCard(
                context,
                icon: Icons.check_circle_outline,
                label: 'Resolved Today',
                value: '$resolvedToday',
                bg: isDark ? _resolvedFg.withOpacity(0.18) : _resolvedBg,
                fg: _resolvedFg,
                surface: surface,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color bg,
    required Color fg,
    required Color surface,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : _borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: fg, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(
    BuildContext context, {
    required Warning warning,
    required Color onSurface,
    required Color secondary,
    required VoidCallback onTakeAction,
    required VoidCallback onDismiss,
  }) {
    final isCritical = warning.severity == WarningSeverity.urgent;
    final isHigh = warning.severity == WarningSeverity.high;
    final isMedium = warning.severity == WarningSeverity.medium;
    final cardBg = isCritical
        ? _criticalBg
        : (isHigh ? _highBg : (isMedium ? _mediumBg : _highBg));
    final fg = isCritical
        ? _criticalFg
        : (isHigh ? _highFg : (isMedium ? _mediumFg : AppTheme.primaryBlue));
    final severityLabel = warning.severity == WarningSeverity.urgent
        ? 'critical'
        : warning.severity == WarningSeverity.high
            ? 'high'
            : warning.severity.name;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: fg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCritical
                      ? Icons.warning_amber_rounded
                      : (isHigh ? Icons.error_outline : Icons.info_outline),
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            warning.title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: fg.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            severityLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: fg,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      warning.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: secondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: secondary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            warning.category ?? '—',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: secondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.schedule, size: 14, color: secondary),
                        const SizedBox(width: 4),
                        Text(
                          warning.timeAgo ?? '—',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTakeAction,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Text(
                        warning.task != null ? 'Take Action' : warning.action,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: secondary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Dismiss',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color secondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: _resolvedFg.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'No active warnings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: secondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nothing needs attention right now based on your task deadlines.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class Warning {
  final String id;
  final Task? task;
  final WarningType type;
  final String title;
  final String message;
  final WarningSeverity severity;
  final String action;
  final String? category;
  final String? timeAgo;

  Warning({
    required this.id,
    this.task,
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    required this.action,
    this.category,
    this.timeAgo,
  });
}

enum WarningType {
  missedTask,
  deadline,
  workload,
  burnout,
}

enum WarningSeverity {
  low,
  medium,
  high,
  urgent,
}
