import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/task.dart';

class PriorityTag extends StatelessWidget {
  final TaskPriority priority;
  
  const PriorityTag({super.key, required this.priority});
  
  Color _getColor() {
    switch (priority) {
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
    final color = _getColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
