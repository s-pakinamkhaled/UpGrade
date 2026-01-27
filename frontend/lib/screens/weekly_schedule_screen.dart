import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../models/task.dart';

class WeeklyScheduleScreen extends StatelessWidget {
  final DateTime weekStart;
  final Map<DateTime, List<Task>> weeklyTasks;

  const WeeklyScheduleScreen({
    super.key,
    required this.weekStart,
    required this.weeklyTasks,
  });

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  List<DateTime> get weekDays =>
      List.generate(7, (i) => weekStart.add(Duration(days: i)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Schedule'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: weekDays.map((date) {
          final tasks = weeklyTasks[_dateOnly(date)] ?? [];
          if (tasks.isEmpty) return const SizedBox.shrink();

          return _dayCard(date, tasks);
        }).toList(),
      ),
    );
  }

  Widget _dayCard(DateTime date, List<Task> tasks) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  DateFormat('EEEE').format(date),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d').format(date),
                  style: TextStyle(color: AppTheme.mediumGray),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...tasks.map(_taskRow),
          ],
        ),
      ),
    );
  }

  Widget _taskRow(Task task) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            _priorityIcon(task.priority),
            size: 16,
            color: _priorityColor(task.priority),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              task.title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (task.scheduledTime != null)
            Text(
              DateFormat('h:mm a').format(task.scheduledTime!),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.mediumGray,
              ),
            ),
        ],
      ),
    );
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.urgent:
        return AppTheme.errorRed;
      case TaskPriority.high:
        return AppTheme.warningOrange;
      case TaskPriority.medium:
        return AppTheme.primaryBlue;
      case TaskPriority.low:
        return AppTheme.mediumGray;
    }
  }

  IconData _priorityIcon(TaskPriority p) {
    switch (p) {
      case TaskPriority.urgent:
        return Icons.priority_high;
      case TaskPriority.high:
        return Icons.trending_up;
      case TaskPriority.medium:
        return Icons.remove;
      case TaskPriority.low:
        return Icons.arrow_downward;
    }
  }
}
