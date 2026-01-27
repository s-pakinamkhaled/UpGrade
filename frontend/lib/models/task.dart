class Task {
  final String id;
  final String title;
  final String? description;
  final DateTime deadline;
  final String courseId;
  final String courseName;
  final TaskPriority priority;
  final TaskStatus status;
  final int estimatedMinutes;
  final DateTime? scheduledTime;
  final DateTime? completedAt;
  
  Task({
    required this.id,
    required this.title,
    this.description,
    required this.deadline,
    required this.courseId,
    required this.courseName,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.pending,
    required this.estimatedMinutes,
    this.scheduledTime,
    this.completedAt,
  });
  
  bool get isOverdue => deadline.isBefore(DateTime.now()) && status != TaskStatus.completed;
  bool get isToday => scheduledTime != null && 
    scheduledTime!.year == DateTime.now().year &&
    scheduledTime!.month == DateTime.now().month &&
    scheduledTime!.day == DateTime.now().day;
}

enum TaskPriority {
  low,
  medium,
  high,
  urgent,
}

enum TaskStatus {
  pending,
  inProgress,
  completed,
  missed,
}

extension TaskPriorityExtension on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.urgent:
        return 'Urgent';
    }
  }
}
