import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/task.dart';
import '../widgets/upgrade_visual_system.dart';

List<Color> _weekAccent(String id) {
  const options = [
    [Color(0xFFFFF7ED), Color(0xFFF97316)],
    [Color(0xFFFFF1F2), Color(0xFFEC4899)],
    [Color(0xFFEEF2FF), Color(0xFF6366F1)],
    [Color(0xFFE0F2FE), Color(0xFF0EA5E9)],
    [Color(0xFFF5F3FF), Color(0xFF8B5CF6)],
    [Color(0xFFECFDF5), Color(0xFF10B981)],
  ];
  return options[id.hashCode.abs() % options.length];
}

class WeeklyScheduleScreen extends StatelessWidget {
  final DateTime weekStart;
  final Map<DateTime, List<Task>> weeklyTasks;

  const WeeklyScheduleScreen({
    super.key,
    required this.weekStart,
    required this.weeklyTasks,
  });

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => weekStart.add(Duration(days: i)));

  static final _deadlineFormat = DateFormat('EEE, MMM d · h:mm a');

  /// All tasks for this week in one list (deduped by id), sorted by deadline.
  List<Task> _allWeekTasksSorted() {
    final seen = <String>{};
    final out = <Task>[];
    for (final d in _weekDays) {
      for (final task in weeklyTasks[_dateOnly(d)] ?? []) {
        if (seen.add(task.id)) out.add(task);
      }
    }
    out.sort((a, b) {
      if (a.hasRealDeadline != b.hasRealDeadline) {
        return a.hasRealDeadline ? -1 : 1;
      }
      return a.deadline.compareTo(b.deadline);
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        title: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
          child: const Text(
            'Weekly schedule',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -0.4,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: DecoratedBox(
        decoration: UpGradePageDecor.pageBackground(isDark),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final t = UpGradeRem(constraints.maxWidth);
            final totalTasks = _weekDays.fold<int>(
              0,
              (s, d) => s + (weeklyTasks[_dateOnly(d)]?.length ?? 0),
            );
            final allTasks = _allWeekTasksSorted();

            if (totalTasks == 0) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(t.space(1.2)),
                  child: UpGradeGradientFrameCard(
                    rem: t,
                    isDark: isDark,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_available_rounded,
                          size: t.iconSmall * 2,
                          color: AppTheme.secondaryPurple,
                        ),
                        SizedBox(height: t.space(0.65)),
                        Text(
                          'No tasks this week',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: t.sectionTitle,
                            fontWeight: FontWeight.w800,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: t.space(0.35)),
                        Text(
                          'When you add assignments with due dates, they will show here in one list.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: t.cardBody,
                            height: 1.4,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                t.space(0.85),
                0,
                t.space(0.85),
                t.space(1.4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UpGradeMutedSubtitle(
                    '${DateFormat.MMMd().format(_weekDays.first)} – ${DateFormat.MMMd().format(_weekDays.last)} · ${allTasks.length} task${allTasks.length == 1 ? '' : 's'}',
                    rem: t,
                    isDark: isDark,
                  ),
                  SizedBox(height: t.space(0.65)),
                  UpGradeGradientFrameCard(
                    rem: t,
                    isDark: isDark,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        t.space(0.75),
                        t.space(0.85),
                        t.space(0.75),
                        t.space(0.95),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'All tasks this week',
                            style: TextStyle(
                              fontSize: t.sectionTitle,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.35,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: t.space(0.2)),
                          Text(
                            'Sorted by deadline',
                            style: TextStyle(
                              fontSize: t.listSubtitle,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.55),
                            ),
                          ),
                          SizedBox(height: t.space(0.75)),
                          ...allTasks.map(
                            (task) => Padding(
                              padding: EdgeInsets.only(bottom: t.space(0.55)),
                              child: _TaskListCard(
                                task: task,
                                isDark: isDark,
                                rem: t,
                                deadlineFormat: _deadlineFormat,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TaskListCard extends StatelessWidget {
  const _TaskListCard({
    required this.task,
    required this.isDark,
    required this.rem,
    required this.deadlineFormat,
  });

  final Task task;
  final bool isDark;
  final UpGradeRem rem;
  final DateFormat deadlineFormat;

  @override
  Widget build(BuildContext context) {
    final pair = _weekAccent(task.id);
    final strong = pair[1];
    final titleColor =
        isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : AppTheme.mediumGray;
    final deadlineLabel = task.hasRealDeadline
        ? deadlineFormat.format(task.deadline)
        : 'No deadline';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).pushNamed(
            AppConstants.routeTaskExecution,
            arguments: task,
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : pair[0],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: strong.withOpacity(isDark ? 0.45 : 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: strong.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(14),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [strong, strong.withOpacity(0.65)],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      rem.space(0.55),
                      rem.space(0.5),
                      rem.space(0.55),
                      rem.space(0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: rem.listTitle,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                            color: titleColor,
                          ),
                        ),
                        if (task.courseName.isNotEmpty) ...[
                          SizedBox(height: rem.space(0.25)),
                          Text(
                            task.courseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: rem.cardBody,
                              fontWeight: FontWeight.w600,
                              color: strong,
                            ),
                          ),
                        ],
                        SizedBox(height: rem.space(0.35)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.event_rounded,
                              size: 16,
                              color: subColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Deadline: $deadlineLabel',
                                style: TextStyle(
                                  fontSize: rem.listSubtitle,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                  color: subColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
