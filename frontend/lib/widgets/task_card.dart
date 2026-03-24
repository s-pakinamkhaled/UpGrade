import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onReschedule;
  final VoidCallback? onTap;
  
  const TaskCard({
    super.key,
    required this.task,
    this.onReschedule,
    this.onTap,
  });
  
  Color _getPriorityColor() {
    switch (task.priority) {
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
  
  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor();
    final isOverdue = task.isOverdue;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isOverdue 
              ? AppTheme.errorRed.withOpacity(0.2)
              : AppTheme.mediumGray.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: isOverdue
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.errorRed.withOpacity(0.05),
                      AppTheme.errorRed.withOpacity(0.02),
                    ],
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: priorityColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        task.priority.label,
                        style: TextStyle(
                          color: priorityColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (onReschedule != null)
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextButton.icon(
                          onPressed: onReschedule,
                          icon: Icon(Icons.schedule, size: 14, color: AppTheme.primaryBlue),
                          label: Text(
                            'Reschedule',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                if (task.description != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    task.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.darkText.withOpacity(0.65),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.book,
                        size: 14,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      task.courseName,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.darkText.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isOverdue
                            ? AppTheme.errorRed.withOpacity(0.1)
                            : AppTheme.mediumGray.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.access_time,
                        size: 14,
                        color: isOverdue ? AppTheme.errorRed : AppTheme.mediumGray,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MMM d, h:mm a').format(task.deadline),
                      style: TextStyle(
                        fontSize: 12,
                        color: isOverdue ? AppTheme.errorRed : AppTheme.mediumGray,
                        fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
