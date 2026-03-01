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
  /// Grade received (from Classroom), if returned by teacher.
  final double? assignedGrade;
  /// Max points for this assignment (from Classroom).
  final int? maxPoints;

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
    this.assignedGrade,
    this.maxPoints,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      deadline: DateTime.tryParse(json['deadline'] as String? ?? '') ?? DateTime.now(),
      courseId: json['courseId'] as String? ?? '',
      courseName: json['courseName'] as String? ?? '',
      priority: _priorityFromString(json['priority'] as String?),
      status: _statusFromString(json['status'] as String?),
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt() ?? 30,
      scheduledTime: json['scheduledTime'] != null
          ? DateTime.tryParse(json['scheduledTime'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      assignedGrade: (json['assignedGrade'] as num?)?.toDouble(),
      maxPoints: (json['maxPoints'] as num?)?.toInt(),
    );
  }

  static TaskPriority _priorityFromString(String? s) {
    switch (s) {
      case 'urgent': return TaskPriority.urgent;
      case 'high': return TaskPriority.high;
      case 'low': return TaskPriority.low;
      default: return TaskPriority.medium;
    }
  }

  static TaskStatus _statusFromString(String? s) {
    switch (s) {
      case 'completed': return TaskStatus.completed;
      case 'inProgress': return TaskStatus.inProgress;
      case 'missed': return TaskStatus.missed;
      default: return TaskStatus.pending;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'deadline': deadline.toIso8601String(),
        'courseId': courseId,
        'courseName': courseName,
        'priority': priority.name,
        'status': status.name,
        'estimatedMinutes': estimatedMinutes,
        'scheduledTime': scheduledTime?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'assignedGrade': assignedGrade,
        'maxPoints': maxPoints,
      };

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
