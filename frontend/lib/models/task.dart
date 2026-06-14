class Task {
  final String id;
  final String title;
  final String? description;
  final DateTime deadline;
  final String courseId;
  final String courseName;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime? startedAt;
  final int estimatedMinutes;
  final DateTime? scheduledTime;
  final DateTime? completedAt;
  final DateTime updatedAt;
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
    this.startedAt,
    required this.estimatedMinutes,
    this.scheduledTime,
    this.completedAt,
    DateTime? updatedAt,
    this.assignedGrade,
    this.maxPoints,
  }) : updatedAt = updatedAt ?? DateTime.now();

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
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'] as String)
          : null,
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt() ?? 30,
      scheduledTime: json['scheduledTime'] != null
          ? DateTime.tryParse(json['scheduledTime'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      assignedGrade: json['assignedGrade'] is num
          ? (json['assignedGrade'] as num).toDouble()
          : null,
      maxPoints: json['maxPoints'] is num
          ? (json['maxPoints'] as num).toInt()
          : null,
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
        'startedAt': startedAt?.toIso8601String(),
        'estimatedMinutes': estimatedMinutes,
        'scheduledTime': scheduledTime?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'assignedGrade': assignedGrade,
        'maxPoints': maxPoints,
      };

  Task copyWith({
    TaskStatus? status,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id,
      title: title,
      description: description,
      deadline: deadline,
      courseId: courseId,
      courseName: courseName,
      priority: priority,
      status: status ?? this.status,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      estimatedMinutes: estimatedMinutes,
      scheduledTime: scheduledTime,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      updatedAt: updatedAt ?? this.updatedAt,
      assignedGrade: assignedGrade,
      maxPoints: maxPoints,
    );
  }

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
