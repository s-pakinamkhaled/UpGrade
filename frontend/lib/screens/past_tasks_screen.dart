import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/constants.dart';
import '../models/task.dart';
import '../providers/classroom_provider.dart';

/// Shows all past tasks (deadline before today) with status: submitted/completed or missing.
/// Grades shown when available. Links to Missed Tasks page.
class PastTasksScreen extends StatelessWidget {
  const PastTasksScreen({super.key});

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  static List<Task> _pastTasks(List<Task> tasks) {
    final today = _dateOnly(DateTime.now());
    return tasks
        .where((t) => _dateOnly(t.deadline).isBefore(today))
        .toList()
      ..sort((a, b) => b.deadline.compareTo(a.deadline));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Tasks'),
      ),
      body: Consumer<ClassroomProvider>(
        builder: (context, provider, _) {
          final allTasks = provider.tasks;
          final past = _pastTasks(allTasks);
          final missed = past.where((t) => t.status == TaskStatus.missed).toList();

          if (past.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_edu,
                      size: 64,
                      color: AppTheme.primaryBlue.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No past tasks yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tasks with deadlines that have passed will appear here.',
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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (missed.isNotEmpty) ...[
                Card(
                  color: AppTheme.errorRed.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppTheme.errorRed.withOpacity(0.3)),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        AppConstants.routeMissedTasks,
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.errorRed.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: AppTheme.errorRed,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${missed.length} missed assignment${missed.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.darkText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'View all missed tasks and get an AI catch-up plan',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.darkText.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: AppTheme.errorRed,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'All past tasks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mediumGray,
                  ),
                ),
              ),
              ...past.map((task) => _PastTaskCard(task: task)),
            ],
          );
        },
      ),
    );
  }
}

class _PastTaskCard extends StatelessWidget {
  final Task task;

  const _PastTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final isMissed = task.status == TaskStatus.missed;
    final hasGrade = task.assignedGrade != null || task.maxPoints != null;

    String statusLabel;
    Color statusColor;
    IconData statusIcon;
    if (isMissed) {
      statusLabel = 'Missing';
      statusColor = AppTheme.errorRed;
      statusIcon = Icons.cancel_outlined;
    } else {
      statusLabel = 'Submitted';
      statusColor = AppTheme.successGreen;
      statusIcon = Icons.check_circle_outline;
    }

    String? gradeText;
    if (hasGrade && task.assignedGrade != null) {
      gradeText = task.maxPoints != null
          ? '${task.assignedGrade!.toStringAsFixed(0)} / ${task.maxPoints}'
          : '${task.assignedGrade!.toStringAsFixed(0)}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isMissed
            ? BorderSide(color: AppTheme.errorRed.withOpacity(0.3))
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  statusIcon,
                  size: 22,
                  color: statusColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.courseName.isNotEmpty
                            ? '${task.title} / ${task.courseName}'
                            : task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, y').format(task.deadline),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.mediumGray,
                        ),
                      ),
                      if (gradeText != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Grade: $gradeText',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
