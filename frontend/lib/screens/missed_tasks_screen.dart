import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/dashboard_shell_navigation.dart';
import '../core/theme.dart';
import '../models/task.dart';
import '../providers/classroom_provider.dart';
import '../widgets/upgrade_visual_system.dart';

/// Shows only missed tasks. Student can review them and open AI to get a catch-up plan.
class MissedTasksScreen extends StatelessWidget {
  const MissedTasksScreen({super.key});

  static const String _pageSubtitle =
      'Review past-due assignments and get back on track with AI.';

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static List<Task> _missedTasks(List<Task> tasks) {
    final today = _dateOnly(DateTime.now());
    return tasks
        .where((t) =>
            t.hasRealDeadline &&
            _dateOnly(t.deadline).isBefore(today) &&
            t.status != TaskStatus.completed)
        .toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
  }

  double _shellInnerMaxWidth(double bodyWidth) {
    if (bodyWidth <= 0) return 640;
    return (bodyWidth - 40).clamp(640.0, 1320.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wide = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: DecoratedBox(
        decoration: UpGradePageDecor.pageBackground(isDark),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxCard = wide
                  ? _shellInnerMaxWidth(constraints.maxWidth)
                  : constraints.maxWidth;
              final hPad =
                  wide ? (constraints.maxWidth > 1100 ? 28.0 : 20.0) : 16.0;
              final vPad = wide
                  ? (constraints.maxHeight > 800 ? 20.0 : 16.0)
                  : 12.0;
              final rem = UpGradeRem(
                wide
                    ? maxCard
                    : (maxCard - hPad * 2).clamp(280.0, 520.0),
              );
              final innerContentW = wide
                  ? (maxCard - rem.space(1.2) * 2 - 4).clamp(260.0, 2000.0)
                  : (maxCard - hPad * 2).clamp(260.0, 520.0);
              final bodyRem = UpGradeRem(innerContentW);
              final titleAlign =
                  !wide || maxCard > 960 ? TextAlign.start : TextAlign.center;
              final titleAlignment = titleAlign == TextAlign.start
                  ? Alignment.centerLeft
                  : Alignment.center;

              return SingleChildScrollView(
                padding:
                    EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: wide ? maxCard : double.infinity,
                      minHeight:
                          wide ? constraints.maxHeight - vPad * 2 : 0,
                    ),
                    child: UpGradeGradientFrameCard(
                      rem: rem,
                      isDark: isDark,
                      child: Consumer<ClassroomProvider>(
                        builder: (context, provider, _) {
                          final missed = _missedTasks(provider.tasks);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Align(
                                alignment: titleAlignment,
                                child: UpGradeGradientTitle(
                                  'Missed Tasks',
                                  rem: rem,
                                  isDark: isDark,
                                ),
                              ),
                              SizedBox(height: rem.space(0.35)),
                              Align(
                                alignment: titleAlignment,
                                child: UpGradeMutedSubtitle(
                                  _pageSubtitle,
                                  rem: rem,
                                  isDark: isDark,
                                ),
                              ),
                              SizedBox(height: rem.space(1.0)),
                              if (missed.isEmpty)
                                _EmptyMissedState(rem: bodyRem, isDark: isDark)
                              else ...[
                                _MissedInfoBanner(rem: bodyRem, isDark: isDark),
                                SizedBox(height: bodyRem.space(0.85)),
                                ...missed.map(
                                  (task) => Padding(
                                    padding: EdgeInsets.only(
                                      bottom: bodyRem.space(0.55),
                                    ),
                                    child: _MissedTaskCard(
                                      task: task,
                                      rem: bodyRem,
                                      isDark: isDark,
                                    ),
                                  ),
                                ),
                                SizedBox(height: bodyRem.space(0.85)),
                                _BuildAIPlanButton(
                                  missedCount: missed.length,
                                  rem: bodyRem,
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyMissedState extends StatelessWidget {
  final UpGradeRem rem;
  final bool isDark;

  const _EmptyMissedState({
    required this.rem,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final secondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: rem.space(2.0)),
      child: Column(
        children: [
          Container(
            width: rem.space(5.5),
            height: rem.space(5.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppTheme.successGreen.withOpacity(0.24),
                        AppTheme.primaryBlue.withOpacity(0.18),
                      ]
                    : [
                        const Color(0xFFD1FAE5),
                        const Color(0xFFDBEAFE),
                      ],
              ),
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: rem.iconSmall * 2.2,
              color: isDark ? AppTheme.white : AppTheme.successGreen,
            ),
          ),
          SizedBox(height: rem.space(0.85)),
          Text(
            'No missed tasks',
            style: TextStyle(
              fontSize: rem.cardTitle,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.darkText,
            ),
          ),
          SizedBox(height: rem.space(0.35)),
          Text(
            'You\'re all caught up. Missed assignments will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: rem.cardBody,
              height: 1.45,
              color: secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissedInfoBanner extends StatelessWidget {
  final UpGradeRem rem;
  final bool isDark;

  const _MissedInfoBanner({
    required this.rem,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(rem.space(0.85)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppTheme.errorRed.withOpacity(0.16),
                  AppTheme.warningOrange.withOpacity(0.12),
                ]
              : [
                  const Color(0xFFFFF1F2),
                  const Color(0xFFFFF7ED),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.errorRed.withOpacity(isDark ? 0.35 : 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppTheme.primaryBlue,
            size: rem.iconSmall * 1.2,
          ),
          SizedBox(width: rem.space(0.65)),
          Expanded(
            child: Text(
              'These assignments are past due. Use the button below to get a personalized catch-up plan from the AI.',
              style: TextStyle(
                fontSize: rem.cardBody,
                color: isDark ? Colors.white.withOpacity(0.88) : AppTheme.darkText,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissedTaskCard extends StatelessWidget {
  final Task task;
  final UpGradeRem rem;
  final bool isDark;

  const _MissedTaskCard({
    required this.task,
    required this.rem,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.errorRed.withOpacity(isDark ? 0.35 : 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.errorRed.withOpacity(isDark ? 0.08 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(rem.space(0.85)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: rem.space(2.0),
            height: rem.space(2.0),
            decoration: BoxDecoration(
              color: AppTheme.errorRed.withOpacity(isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.assignment_late_rounded,
              size: rem.iconSmall,
              color: AppTheme.errorRed,
            ),
          ),
          SizedBox(width: rem.space(0.65)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.courseName.isNotEmpty
                      ? '${task.title} / ${task.courseName}'
                      : task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: rem.listTitle,
                    color: isDark ? Colors.white : AppTheme.darkText,
                  ),
                ),
                SizedBox(height: rem.space(0.25)),
                Text(
                  'Due: ${DateFormat('MMM d, y').format(task.deadline)}',
                  style: TextStyle(
                    fontSize: rem.listSubtitle,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : AppTheme.mediumGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildAIPlanButton extends StatelessWidget {
  final int missedCount;
  final UpGradeRem rem;

  const _BuildAIPlanButton({
    required this.missedCount,
    required this.rem,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.softShadow,
        ),
        child: ElevatedButton.icon(
          onPressed: () {
            selectMainShellRoute(
              context,
              AppConstants.routeAIChatbot,
            );
          },
          icon: const Icon(Icons.auto_awesome_rounded),
          label: Text(
            missedCount == 1
                ? 'Get AI catch-up plan for 1 missed task'
                : 'Get AI catch-up plan for $missedCount missed tasks',
            style: TextStyle(
              fontSize: rem.buttonLabel,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: AppTheme.white,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.symmetric(vertical: rem.space(0.85)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}
