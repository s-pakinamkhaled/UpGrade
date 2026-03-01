import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/task.dart';
import '../models/focus_session.dart';
import '../providers/classroom_provider.dart';
import '../widgets/app_logo.dart';
import 'weekly_schedule_screen.dart';

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

  // Focus/breaks are optional local data; main tasks come from Classroom
  final List<BreakSession> _todayBreaks = [];
  final List<FocusSession> _todayFocusSessions = [];

  @override
  void initState() {
    super.initState();
    _weekStart = _dateOnly(DateTime.now());
  }

  /// Tasks with deadline on or after today (excludes past).
  static List<Task> _upcomingTasksOnly(List<Task> tasks, DateTime today) {
    return tasks.where((t) => !_dateOnly(t.deadline).isBefore(today)).toList();
  }

  /// Build map of date -> tasks from Classroom (grouped by deadline date).
  static Map<DateTime, List<Task>> _weeklyTasksFromProvider(List<Task> tasks) {
    final map = <DateTime, List<Task>>{};
    for (final t in tasks) {
      final d = _dateOnly(t.deadline);
      map.putIfAbsent(d, () => []).add(t);
    }
    return map;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClassroomProvider>();
    final allTasks = provider.tasks;
    final upcomingTasks = _upcomingTasksOnly(allTasks, _today);
    // Use all tasks so past days show their (graded) assignments too
    final weeklyTasks = _weeklyTasksFromProvider(allTasks);
    final selectedDayTasks = weeklyTasks[_dateOnly(_selectedDate)] ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: widget.openDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.openDrawer,
                tooltip: 'Open menu',
              )
            : null,
        title: Row(
          children: [
            const SizedBox(width: 36, height: 36, child: AppLogo.small()),
            const SizedBox(width: 10),
            const Text('UpGrade', style: TextStyle(fontWeight: FontWeight.bold)),
            if (provider.syncedAt != null) ...[
              const SizedBox(width: 8),
              Text(
                selectedDayTasks.length == upcomingTasks.length
                    ? '${upcomingTasks.length} tasks'
                    : '${selectedDayTasks.length} here · ${upcomingTasks.length} total',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
      body: Column(
        children: [
          _buildWeekHeader(),
          Expanded(
            child: allTasks.isEmpty
                ? _buildEmptyState(provider.syncedAt == null)
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildDailySection(selectedDayTasks),
                        _buildWeeklyNavigationCard(weeklyTasks),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool neverSynced) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: AppTheme.primaryBlue.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              neverSynced
                  ? 'Sync Google Classroom to see your assignments and deadlines here.'
                  : 'No assignments due this week.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.darkText.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- WEEK HEADER ----------------

  Widget _buildWeekHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.white,
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          // Left arrow – previous 7 days
          IconButton(
            onPressed: _scrollStripLeft,
            icon: const Icon(Icons.chevron_left),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
            ),
            tooltip: 'Previous week',
          ),
          const SizedBox(width: 4),
          // 7-day strip
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
              child: GestureDetector(
                onTap: () => setState(() => _selectedDayIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppTheme.primaryGradient : null,
                    color: !isSelected && isHovered
                        ? AppTheme.primaryBlue.withOpacity(0.12)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    border: isToday && !isSelected
                        ? Border.all(color: AppTheme.primaryBlue, width: 2)
                        : isHovered && !isSelected
                            ? Border.all(
                                color: AppTheme.primaryBlue.withOpacity(0.4),
                                width: 1.5,
                              )
                            : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        _isSameDay(date, _today)
                            ? 'Today'
                            : _isSameDay(date, _today.add(const Duration(days: 1)))
                                ? 'Tomorrow'
                                : DateFormat('E').format(date),
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? AppTheme.white
                              : AppTheme.mediumGray,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              isSelected ? AppTheme.white : AppTheme.darkText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
            ),
          ),
          const SizedBox(width: 4),
          // Calendar – pick any day
          IconButton(
            onPressed: _openCalendarPicker,
            icon: const Icon(Icons.calendar_month),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
            ),
            tooltip: 'Pick a date',
          ),
          const SizedBox(width: 4),
          // Right arrow – next 7 days
          IconButton(
            onPressed: _scrollStripRight,
            icon: const Icon(Icons.chevron_right),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
            ),
            tooltip: 'Next week',
          ),
        ],
      ),
    );
  }

  // ---------------- DAILY SECTION ----------------

  Widget _buildDailySection(List<Task> selectedDayTasks) {
    return Column(
      children: [
        _sectionHeader(
          title: 'Daily Schedule',
          subtitle: '${selectedDayTasks.length} tasks',
          icon: Icons.schedule,
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: _buildTimelineItems(selectedDayTasks)),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              DateFormat('h:mm a').format(item.time),
              style: const TextStyle(fontWeight: FontWeight.w600),
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
        return _simpleCard(
            item.breakSession!.type == BreakType.lunch
                ? 'Lunch Break'
                : 'Short Break');
      case TimelineItemType.focusSession:
        return _simpleCard('Focus Session');
    }
  }

  // ---------------- WEEKLY NAVIGATION ----------------

  Widget _buildWeeklyNavigationCard(Map<DateTime, List<Task>> weeklyTasks) {
    return InkWell(
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
      child: _sectionHeader(
        title: 'Weekly Schedule',
        subtitle: 'All tasks this week',
        icon: Icons.view_week,
      ),
    );
  }

  // ---------------- COMPONENTS ----------------

  Widget _sectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              Text(subtitle,
                  style: TextStyle(color: AppTheme.mediumGray)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _taskCard(Task task) {
    final hasGrade = task.assignedGrade != null || task.maxPoints != null;
    final gradeText = hasGrade
        ? (task.maxPoints != null && task.assignedGrade != null
            ? 'Grade: ${task.assignedGrade!.toStringAsFixed(0)} / ${task.maxPoints}'
            : task.assignedGrade != null
                ? 'Grade: ${task.assignedGrade!.toStringAsFixed(0)}'
                : null)
        : null;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              task.courseName.isNotEmpty
                  ? '${task.title} / ${task.courseName}'
                  : task.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (gradeText != null) ...[
              const SizedBox(height: 6),
              Text(
                gradeText,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _simpleCard(String text) => Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
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
