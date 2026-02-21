import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/constants.dart';
import '../models/task.dart';
import '../providers/classroom_provider.dart';

/// Shows only missed tasks. Student can review them and open AI to get a catch-up plan.
class MissedTasksScreen extends StatelessWidget {
  const MissedTasksScreen({super.key});

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  static List<Task> _missedTasks(List<Task> tasks) {
    final today = _dateOnly(DateTime.now());
    return tasks
        .where((t) =>
            _dateOnly(t.deadline).isBefore(today) &&
            t.status == TaskStatus.missed)
        .toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Missed Tasks'),
      ),
      body: Consumer<ClassroomProvider>(
        builder: (context, provider, _) {
          final missed = _missedTasks(provider.tasks);

          if (missed.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: AppTheme.successGreen.withOpacity(0.7),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No missed tasks',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You\'re all caught up. Missed assignments will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to Past Tasks'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.errorRed.withOpacity(0.08),
                            AppTheme.warningOrange.withOpacity(0.06),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.errorRed.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppTheme.primaryBlue,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'These assignments are past due. Use the button below to get a personalized catch-up plan from the AI.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.darkText.withOpacity(0.85),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...missed.map((task) => _MissedTaskCard(task: task)),
                  ],
                ),
              ),
              _BuildAIPlanButton(missedCount: missed.length),
            ],
          );
        },
      ),
    );
  }
}

class _MissedTaskCard extends StatelessWidget {
  final Task task;

  const _MissedTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.errorRed.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.assignment_late,
              size: 24,
              color: AppTheme.errorRed,
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
                    'Due: ${DateFormat('MMM d, y').format(task.deadline)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.mediumGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildAIPlanButton extends StatelessWidget {
  final int missedCount;

  const _BuildAIPlanButton({required this.missedCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed(AppConstants.routeAIChatbot);
            },
            icon: const Icon(Icons.auto_awesome),
            label: Text(
              missedCount == 1
                  ? 'Get AI catch-up plan for 1 missed task'
                  : 'Get AI catch-up plan for $missedCount missed tasks',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: AppTheme.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
