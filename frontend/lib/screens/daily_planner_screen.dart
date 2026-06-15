import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/constants.dart';
import '../core/dashboard_shell_navigation.dart';
import '../models/task.dart';
import '../models/focus_session.dart';
import '../providers/classroom_provider.dart';
import '../widgets/upgrade_visual_system.dart';
import 'weekly_schedule_screen.dart';

List<Color> _plannerAccentForTask(String id) {
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

class DailyPlannerScreen extends StatefulWidget {
  final VoidCallback? openDrawer;

  const DailyPlannerScreen({super.key, this.openDrawer});

  @override
  State<DailyPlannerScreen> createState() => _DailyPlannerScreenState();
}

class _DailyPlannerScreenState extends State<DailyPlannerScreen> {
  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime get _today => _dateOnly(DateTime.now());

  /// First day of the visible 7-day strip. Arrows/calendar change this.
  late DateTime _weekStart;
  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  int _selectedDayIndex = 0;
  int? _hoveredDayIndex;
  DateTime get _selectedDate => _weekDays[_selectedDayIndex];

  void _scrollStripLeft() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  }

  void _scrollStripRight() {
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
  }

  Future<void> _openCalendarPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null || !mounted) return;
    final startOfWeek = picked.subtract(Duration(days: picked.weekday - 1));
    setState(() {
      _weekStart = _dateOnly(startOfWeek);
      _selectedDayIndex = picked.weekday - 1;
    });
  }

  // Focus/breaks are optional local data; tasks come from ClassroomProvider (Classroom + manual).
  final List<BreakSession> _todayBreaks = [];
  final List<FocusSession> _todayFocusSessions = [];

  @override
  void initState() {
    super.initState();
    _weekStart = _dateOnly(DateTime.now());
  }

  /// Map date → tasks for that calendar day.
  /// Includes Google Classroom and manual tasks (`manual_*` ids) from [ClassroomProvider.tasks].
  /// A task appears on its deadline day and, if different, on its [Task.scheduledTime] day.
  static Map<DateTime, List<Task>> _weeklyTasksFromProvider(List<Task> tasks) {
    final map = <DateTime, List<Task>>{};
    for (final t in tasks) {
      DateTime? deadlineDay;
      if (t.hasRealDeadline) {
        deadlineDay = _dateOnly(t.deadline);
        map.putIfAbsent(deadlineDay, () => []).add(t);
      }
      final st = t.scheduledTime;
      if (st != null) {
        final scheduledDay = _dateOnly(st);
        if (deadlineDay == null || scheduledDay != deadlineDay) {
          map.putIfAbsent(scheduledDay, () => []).add(t);
        }
      }
    }
    return map;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _showStatusSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClassroomProvider>();
    final allTasks = provider.tasks;
    final weeklyTasks = _weeklyTasksFromProvider(allTasks);
    final selectedDayTasks = weeklyTasks[_dateOnly(_selectedDate)] ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitle =
        '${DateFormat.yMMMMEEEEd().format(_selectedDate)} · ${selectedDayTasks.length} task${selectedDayTasks.length == 1 ? '' : 's'} for this day';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final t = UpGradeRem(constraints.maxWidth);
          final hPad = t.space(1.05);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (Navigator.canPop(context))
                Padding(
                  padding: EdgeInsets.only(left: 4, top: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back',
                      style: IconButton.styleFrom(
                        foregroundColor:
                            isDark ? Colors.white70 : AppTheme.darkText,
                      ),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),
                ),
              Expanded(
                child: allTasks.isEmpty
                    ? _buildEmptyState(provider.syncedAt == null, t, isDark)
                    : SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          hPad,
                          8,
                          hPad,
                          t.space(1.4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UpGradeGradientTitle(
                              'My Tasks',
                              rem: t,
                              isDark: isDark,
                            ),
                            SizedBox(height: t.space(0.35)),
                            UpGradeMutedSubtitle(subtitle,
                                rem: t, isDark: isDark),
                            SizedBox(height: t.space(1.05)),
                            _buildWeekStripCard(t, isDark),
                            SizedBox(height: t.space(1.0)),
                            _buildDailyTasksCard(t, isDark, selectedDayTasks),
                            SizedBox(height: t.space(0.85)),
                            _buildGeneratePlanCard(t, isDark),
                            SizedBox(height: t.space(0.85)),
                            _buildWeeklyScheduleCard(t, isDark, weeklyTasks),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool neverSynced, UpGradeRem t, bool isDark) {
    final textColor = isDark ? const Color(0xFFE5E7EB) : AppTheme.darkText;
    final subColor =
        isDark ? const Color(0xFF9CA3AF) : AppTheme.darkText.withOpacity(0.7);
    return SingleChildScrollView(
      padding: EdgeInsets.all(t.space(1.1)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UpGradeGradientTitle(
                'My Tasks',
                rem: t,
                isDark: isDark,
              ),
              SizedBox(height: t.space(0.4)),
              UpGradeMutedSubtitle(
                neverSynced
                    ? 'Connect your courses to see tasks and deadlines here.'
                    : 'No upcoming assignments in the synced window.',
                rem: t,
                isDark: isDark,
              ),
              SizedBox(height: t.space(1.1)),
              UpGradeGradientFrameCard(
                rem: t,
                isDark: isDark,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.assignment_turned_in_outlined,
                        size: 32,
                        color: AppTheme.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      neverSynced
                          ? 'Connect Google Classroom'
                          : 'You\'re all set!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      neverSynced
                          ? 'Sync your courses and assignments so UpGrade can build your daily plan.'
                          : 'No assignments due this week. Take a breath or review past material.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: subColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (neverSynced)
                      SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: AppTheme.mediumShadow,
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              selectMainShellRoute(
                                context,
                                AppConstants.routeGoogleClassroomSync,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text(
                              'Connect Google Classroom',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (neverSynced) ...[
                      const SizedBox(height: 10),
                      Text(
                        'UpGrade will automatically fetch your courses and deadlines.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : AppTheme.darkText.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekStripCard(UpGradeRem t, bool isDark) {
    final text = isDark ? const Color(0xFFE5E7EB) : AppTheme.darkText;
    final muted = isDark ? const Color(0xFF9CA3AF) : AppTheme.mediumGray;
    final strip = Row(
      children: [
        IconButton(
          onPressed: _scrollStripLeft,
          icon: const Icon(Icons.chevron_left_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue.withOpacity(0.12),
            foregroundColor: AppTheme.primaryBlue,
          ),
          tooltip: 'Previous week',
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Row(
            children: List.generate(7, (index) {
              final date = _weekDays[index];
              final isSelected = index == _selectedDayIndex;
              final isToday = _isSameDay(date, DateTime.now());
              final isHovered = _hoveredDayIndex == index;
              return Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hoveredDayIndex = index),
                  onExit: (_) => setState(() => _hoveredDayIndex = null),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _selectedDayIndex = index),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient:
                              isSelected ? AppTheme.primaryGradient : null,
                          color: !isSelected && isHovered
                              ? AppTheme.secondaryPurple.withOpacity(0.1)
                              : !isSelected
                                  ? (isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFF8FAFC))
                                  : null,
                          borderRadius: BorderRadius.circular(14),
                          border: isToday && !isSelected
                              ? Border.all(
                                  color: AppTheme.primaryBlue, width: 2)
                              : isHovered && !isSelected
                                  ? Border.all(
                                      color: AppTheme.secondaryPurple
                                          .withOpacity(0.45),
                                      width: 1.5,
                                    )
                                  : Border.all(
                                      color: isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFE2E8F0),
                                    ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.secondaryPurple
                                        .withOpacity(0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          children: [
                            Text(
                              _isSameDay(date, _today)
                                  ? 'Today'
                                  : _isSameDay(
                                      date,
                                      _today.add(const Duration(days: 1)),
                                    )
                                      ? 'Tomorrow'
                                      : DateFormat('E').format(date),
                              style: TextStyle(
                                fontSize: t.listSubtitle,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? AppTheme.white : muted,
                              ),
                            ),
                            SizedBox(height: t.space(0.35)),
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: t.listTitle,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? AppTheme.white : text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: _openCalendarPicker,
          icon: const Icon(Icons.calendar_month_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.secondaryPurple.withOpacity(0.12),
            foregroundColor: AppTheme.secondaryPurple,
          ),
          tooltip: 'Pick a date',
        ),
        IconButton(
          onPressed: _scrollStripRight,
          icon: const Icon(Icons.chevron_right_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue.withOpacity(0.12),
            foregroundColor: AppTheme.primaryBlue,
          ),
          tooltip: 'Next week',
        ),
      ],
    );

    return UpGradeListSectionPanel(
      rem: t,
      isDark: isDark,
      tintTop: const Color(0xFFEEF2FF),
      borderAccent: AppTheme.primaryBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(t.space(0.45)),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Icon(
                  Icons.date_range_rounded,
                  color: Colors.white,
                  size: t.iconSmall * 1.1,
                ),
              ),
              SizedBox(width: t.space(0.55)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This week',
                      style: TextStyle(
                        fontSize: t.sectionTitle,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.35,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: t.space(0.25)),
                    Text(
                      'Tap a day to see its tasks below.',
                      style: TextStyle(
                        fontSize: t.cardBody,
                        height: 1.35,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: t.space(0.85)),
          strip,
        ],
      ),
    );
  }

  Widget _buildDailyTasksCard(
    UpGradeRem t,
    bool isDark,
    List<Task> selectedDayTasks,
  ) {
    return UpGradeAccentStripeCard(
      rem: t,
      isDark: isDark,
      stripeGradient: const [
        AppTheme.primaryBlue,
        AppTheme.secondaryPurple,
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(t.space(0.45)),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryPurple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.task_alt_rounded,
                  color: AppTheme.secondaryPurple,
                  size: t.iconSmall * 1.15,
                ),
              ),
              SizedBox(width: t.space(0.55)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily tasks',
                      style: TextStyle(
                        fontSize: t.sectionTitle,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.35,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: t.space(0.25)),
                    Text(
                      '${selectedDayTasks.length} task${selectedDayTasks.length == 1 ? '' : 's'} · Google Classroom and tasks you add manually',
                      style: TextStyle(
                        fontSize: t.cardBody,
                        height: 1.35,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: t.space(0.95)),
          ..._buildDailyTasksBody(t, isDark, selectedDayTasks),
        ],
      ),
    );
  }

  List<Widget> _buildDailyTasksBody(
    UpGradeRem t,
    bool isDark,
    List<Task> selectedDayTasks,
  ) {
    final rows = _buildTimelineItems(selectedDayTasks);
    if (rows.isEmpty) {
      final muted = isDark ? const Color(0xFF94A3B8) : AppTheme.mediumGray;
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: t.space(0.5)),
          child: Text(
            'No tasks for this day. Add one in My courses or sync Classroom.',
            style: TextStyle(
              fontSize: t.cardBody,
              height: 1.4,
              color: muted,
            ),
          ),
        ),
      ];
    }
    return [Column(children: rows)];
  }

  Widget _buildGeneratePlanCard(UpGradeRem t, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => selectMainShellRoute(
          context,
          AppConstants.routeStudyPlan,
        ),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: AppTheme.mediumShadow,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: t.space(1.1),
              vertical: t.space(0.95),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(t.space(0.45)),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: t.iconSmall * 1.2,
                  ),
                ),
                SizedBox(width: t.space(0.65)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generate AI study plan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: t.cardTitle,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: t.space(0.2)),
                      Text(
                        'Open Study Plan tab with one tap',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontSize: t.listSubtitle,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: t.iconSmall * 1.1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyScheduleCard(
    UpGradeRem t,
    bool isDark,
    Map<DateTime, List<Task>> weeklyTasks,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WeeklyScheduleScreen(
                weekStart: _weekStart,
                weeklyTasks: weeklyTasks,
              ),
            ),
          );
        },
        child: UpGradeAccentStripeCard(
          rem: t,
          isDark: isDark,
          stripeGradient: const [
            Color(0xFF34D399),
            Color(0xFF10B981),
          ],
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(t.space(0.45)),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.view_week_rounded,
                  color: const Color(0xFF059669),
                  size: t.iconSmall * 1.15,
                ),
              ),
              SizedBox(width: t.space(0.55)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly overview',
                      style: TextStyle(
                        fontSize: t.sectionTitle,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.35,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: t.space(0.25)),
                    Text(
                      'See all tasks across the week in a full-screen layout',
                      style: TextStyle(
                        fontSize: t.cardBody,
                        height: 1.35,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.62),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                color: AppTheme.mediumGray,
                size: t.iconSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTimelineItems(List<Task> selectedDayTasks) {
    final items = <TimelineItem>[];

    for (final task in selectedDayTasks) {
      final time = task.scheduledTime ?? task.deadline;
      items.add(TimelineItem(
        time: time,
        type: TimelineItemType.task,
        task: task,
      ));
    }

    if (_isSameDay(_selectedDate, DateTime.now())) {
      for (final b in _todayBreaks) {
        items.add(TimelineItem(
          time: b.startTime,
          type: TimelineItemType.breakSession,
          breakSession: b,
        ));
      }
      for (final f in _todayFocusSessions) {
        items.add(TimelineItem(
          time: f.startTime,
          type: TimelineItemType.focusSession,
          focusSession: f,
        ));
      }
    }

    items.sort((a, b) => a.time.compareTo(b.time));

    return items.map(_buildTimelineRow).toList();
  }

  Widget _buildTimelineRow(TimelineItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF94A3AF) : AppTheme.mediumGray;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                DateFormat('h:mm a').format(item.time),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: muted,
                  height: 1.2,
                ),
              ),
            ),
          ),
          Expanded(child: _buildTimelineContent(item)),
        ],
      ),
    );
  }

  Widget _buildTimelineContent(TimelineItem item) {
    switch (item.type) {
      case TimelineItemType.task:
        return _taskCard(item.task!);
      case TimelineItemType.breakSession:
        return _simpleCard(item.breakSession!.type == BreakType.lunch
            ? 'Lunch Break'
            : 'Short Break');
      case TimelineItemType.focusSession:
        return _simpleCard('Focus Session');
    }
  }

  Widget _taskCard(Task task) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pair = _plannerAccentForTask(task.id);
    final stripe = pair[1];
    final titleColor = isDark ? const Color(0xFFE5E7EB) : AppTheme.darkText;
    final subColor = isDark ? const Color(0xFF9CA3AF) : AppTheme.mediumGray;
    final hasGrade = task.assignedGrade != null || task.maxPoints != null;
    final gradeText = hasGrade
        ? (task.maxPoints != null && task.assignedGrade != null
            ? 'Grade: ${task.assignedGrade!.toStringAsFixed(0)} / ${task.maxPoints}'
            : task.assignedGrade != null
                ? 'Grade: ${task.assignedGrade!.toStringAsFixed(0)}'
                : null)
        : null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            AppConstants.routeTaskExecution,
            arguments: task,
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: stripe.withOpacity(isDark ? 0.35 : 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: stripe.withOpacity(0.12),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [stripe, stripe.withOpacity(0.65)],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (task.courseName.isNotEmpty)
                          Text(
                            task.courseName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: subColor,
                              letterSpacing: 0.1,
                            ),
                          ),
                        if (task.courseName.isNotEmpty)
                          const SizedBox(height: 4),
                        Text(
                          task.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: -0.2,
                            color: titleColor,
                          ),
                        ),
                        if (gradeText != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              gradeText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _buildTaskStatusActions(task),
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

  Widget _buildTaskStatusActions(Task task) {
    final provider = context.read<ClassroomProvider>();
    final isCompleted = task.status == TaskStatus.completed;
    final isPending = task.status == TaskStatus.pending;
    final isInProgress = task.status == TaskStatus.inProgress;

    if (isCompleted) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () async {
            await provider.reopenTask(task.id);
            if (!mounted) return;
            _showStatusSnackBar('Task moved back to pending');
          },
          icon: const Icon(Icons.restart_alt, size: 16),
          label: const Text('Reopen'),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (isPending)
          ElevatedButton.icon(
            onPressed: () async {
              await provider.startTask(task.id);
              if (!mounted) return;
              _showStatusSnackBar('Task moved to in progress');
            },
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('Start'),
          ),
        ElevatedButton.icon(
          onPressed: () async {
            await provider.completeTask(task.id);
            if (!mounted) return;
            _showStatusSnackBar('Task marked as completed');
          },
          icon: const Icon(Icons.check_circle, size: 16),
          label: Text(isInProgress ? 'Complete' : 'Mark Complete'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successGreen,
            foregroundColor: AppTheme.white,
          ),
        ),
      ],
    );
  }

  Widget _simpleCard(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lineColor =
        isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E293B).withOpacity(0.9)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: lineColor.withOpacity(0.35),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.pause_circle_filled_rounded,
                color: lineColor,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? const Color(0xFFE2E8F0) : AppTheme.darkText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- MODELS ----------------

class TimelineItem {
  final DateTime time;
  final TimelineItemType type;
  final Task? task;
  final BreakSession? breakSession;
  final FocusSession? focusSession;

  TimelineItem({
    required this.time,
    required this.type,
    this.task,
    this.breakSession,
    this.focusSession,
  });
}

enum TimelineItemType { task, breakSession, focusSession }

class BreakSession {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final BreakType type;

  BreakSession({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.type,
  });
}

enum BreakType { short, lunch, long }
