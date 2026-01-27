import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../models/task.dart';
import '../models/focus_session.dart';
import '../widgets/app_logo.dart';
import 'weekly_schedule_screen.dart';

class DailyPlannerScreen extends StatefulWidget {
  const DailyPlannerScreen({super.key});

  @override
  State<DailyPlannerScreen> createState() => _DailyPlannerScreenState();
}

class _DailyPlannerScreenState extends State<DailyPlannerScreen> {
  DateTime _selectedWeekStart = _getWeekStart(DateTime.now());
  int _selectedDayIndex = DateTime.now().weekday - 1;

  // ---------------- MOCK DATA ----------------

  final Map<DateTime, List<Task>> _weeklyTasks = {
    _dateOnly(DateTime.now()): [
      Task(
        id: '1',
        title: 'Math Assignment',
        description: 'Chapters 3–4',
        deadline: DateTime.now().add(const Duration(hours: 6)),
        courseId: 'math101',
        courseName: 'Mathematics',
        priority: TaskPriority.high,
        status: TaskStatus.pending,
        estimatedMinutes: 120,
        scheduledTime: DateTime.now().copyWith(hour: 10, minute: 0),
      ),
      Task(
        id: '2',
        title: 'Chemistry Revision',
        deadline: DateTime.now().add(const Duration(days: 1)),
        courseId: 'chem101',
        courseName: 'Chemistry',
        priority: TaskPriority.urgent,
        status: TaskStatus.pending,
        estimatedMinutes: 90,
        scheduledTime: DateTime.now().copyWith(hour: 15, minute: 30),
      ),
    ],
  };

  final List<FocusSession> _todayFocusSessions = [
    FocusSession(
      id: 'f1',
      taskId: '1',
      startTime: DateTime.now().copyWith(hour: 10, minute: 0),
      endTime: DateTime.now().copyWith(hour: 11, minute: 30),
      focusLevel: 8,
      isCompleted: true,
    ),
  ];

  final List<BreakSession> _todayBreaks = [
    BreakSession(
      id: 'b1',
      startTime: DateTime.now().copyWith(hour: 12, minute: 0),
      endTime: DateTime.now().copyWith(hour: 12, minute: 30),
      type: BreakType.lunch,
    ),
  ];

  // ---------------- HELPERS ----------------

  static DateTime _getWeekStart(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _selectedWeekStart.add(Duration(days: i)));

  DateTime get _selectedDate => _weekDays[_selectedDayIndex];

  List<Task> get _selectedDayTasks =>
      _weeklyTasks[_dateOnly(_selectedDate)] ?? [];

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            SizedBox(width: 36, height: 36, child: AppLogo.small()),
            SizedBox(width: 10),
            Text('UpGrade', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildWeekHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildDailySection(),
                  _buildWeeklyNavigationCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- WEEK HEADER ----------------

  Widget _buildWeekHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: List.generate(7, (index) {
          final date = _weekDays[index];
          final isSelected = index == _selectedDayIndex;
          final isToday = _isSameDay(date, DateTime.now());

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDayIndex = index),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.primaryGradient : null,
                  borderRadius: BorderRadius.circular(12),
                  border: isToday && !isSelected
                      ? Border.all(color: AppTheme.primaryBlue, width: 2)
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('E').format(date),
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
          );
        }),
      ),
    );
  }

  // ---------------- DAILY SECTION ----------------

  Widget _buildDailySection() {
    return Column(
      children: [
        _sectionHeader(
          title: 'Daily Schedule',
          subtitle:
              '${_selectedDayTasks.length} tasks today',
          icon: Icons.schedule,
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: _buildTimelineItems()),
        ),
      ],
    );
  }

  List<Widget> _buildTimelineItems() {
    final items = <TimelineItem>[];

    for (final task in _selectedDayTasks) {
      if (task.scheduledTime != null) {
        items.add(TimelineItem(
          time: task.scheduledTime!,
          type: TimelineItemType.task,
          task: task,
        ));
      }
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
        return _simpleCard(item.task!.title);
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

  Widget _buildWeeklyNavigationCard() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WeeklyScheduleScreen(
              weekStart: _selectedWeekStart,
              weeklyTasks: _weeklyTasks,
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
