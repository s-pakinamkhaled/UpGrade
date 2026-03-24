import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../widgets/dashboard_secondary_shell.dart';

/// Warnings & Alerts page: summary stats (Critical, High Priority, Resolved Today)
/// and a list of active alert cards with Take Action / Dismiss.
class WarningsScreen extends StatefulWidget {
  const WarningsScreen({super.key});

  @override
  State<WarningsScreen> createState() => _WarningsScreenState();
}

class _WarningsScreenState extends State<WarningsScreen> {
  // Design colors from spec
  static const Color _criticalBg = Color(0xFFFFF1F2);
  static const Color _criticalFg = Color(0xFFEF4444);
  static const Color _highBg = Color(0xFFFFF7ED);
  static const Color _highFg = Color(0xFFF97316);
  static const Color _resolvedBg = Color(0xFFF0FDF4);
  static const Color _resolvedFg = Color(0xFF22C55E);
  static const Color _mediumBg = Color(0xFFEFF6FF);
  static const Color _mediumFg = Color(0xFF3B82F6);
  static const Color _borderLight = Color(0xFFE2E8F0);

  final List<Warning> _warnings = [
    const Warning(
      type: WarningType.missedTask,
      title: 'Chemistry Assignment Overdue',
      message: 'Lab report was due 2 days ago. Submit as soon as possible to avoid further impact on your grade.',
      severity: WarningSeverity.urgent,
      action: 'Take Action',
      category: 'CHEM101',
      timeAgo: '2 days ago',
    ),
    const Warning(
      type: WarningType.deadline,
      title: 'Math Assignment Due Soon',
      message: 'Assignment 5 is due in 5 hours. Consider prioritizing this task today.',
      severity: WarningSeverity.high,
      action: 'Prioritize this task',
      category: 'MATH201',
      timeAgo: '5 hours ago',
    ),
    const Warning(
      type: WarningType.workload,
      title: 'Heavy Workload Today',
      message: 'You have 8 tasks scheduled for today. Consider rescheduling some to reduce stress.',
      severity: WarningSeverity.medium,
      action: 'Review schedule',
      category: 'Multiple',
      timeAgo: '1 hour ago',
    ),
  ];

  int _resolvedTodayCount = 8;

  int get _criticalCount =>
      _warnings.where((w) => w.severity == WarningSeverity.urgent).length;
  int get _highCount =>
      _warnings.where((w) => w.severity == WarningSeverity.high).length;

  void _dismiss(Warning warning) {
    setState(() {
      _warnings.remove(warning);
      _resolvedTodayCount += 1;
    });
  }

  Widget _buildMainContent(
    BuildContext context,
    Color surface,
    Color onSurface,
    Color secondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(onSurface, secondary),
        const SizedBox(height: 28),
        _buildSummaryRow(context, surface, onSurface),
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
        if (_warnings.isEmpty)
          _buildEmptyState(secondary)
        else
          ..._warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildAlertCard(
                context,
                warning: w,
                onSurface: onSurface,
                secondary: secondary,
                onTakeAction: () {},
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
    final bg = isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF8FAFC);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final secondary = isDark ? const Color(0xFF9CA3AF) : AppTheme.mediumGray;

    final narrow = Scaffold(
      backgroundColor: bg,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _buildMainContent(context, surface, onSurface, secondary),
      ),
    );

    return DashboardSecondaryShell(
      highlightRoute: AppConstants.routeWarnings,
      narrow: narrow,
      wideBody: ColoredBox(
        color: bg,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildMainContent(context, surface, onSurface, secondary),
        ),
      ),
    );
  }

  Widget _buildHeader(Color onSurface, Color secondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Warnings & Alerts',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Proactive notifications to keep you on track',
          style: TextStyle(
            fontSize: 14,
            color: secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    Color surface,
    Color onSurface,
  ) {
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
                value: '$_criticalCount',
                bg: _criticalBg,
                fg: _criticalFg,
                surface: surface,
              ),
              const SizedBox(height: 12),
              _summaryCard(
                context,
                icon: Icons.error_outline,
                label: 'High Priority',
                value: '$_highCount',
                bg: _highBg,
                fg: _highFg,
                surface: surface,
              ),
              const SizedBox(height: 12),
              _summaryCard(
                context,
                icon: Icons.check_circle_outline,
                label: 'Resolved Today',
                value: '$_resolvedTodayCount',
                bg: _resolvedBg,
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
                value: '$_criticalCount',
                bg: _criticalBg,
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
                value: '$_highCount',
                bg: _highBg,
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
                value: '$_resolvedTodayCount',
                bg: _resolvedBg,
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderLight),
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
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
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
                      child: const Text(
                        'Take Action',
                        style: TextStyle(
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
              'You\'re all caught up. We\'ll notify you when something needs attention.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data models ───────────────────────────────────────────────────────────

class Warning {
  final WarningType type;
  final String title;
  final String message;
  final WarningSeverity severity;
  final String action;
  final String? category;
  final String? timeAgo;

  const Warning({
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
