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

  // ── Classification metadata ──────────────────────────────────────
  /// Where this task originated: "google_classroom", "manual", or "unknown".
  final String source;

  /// Semantic type after classification.
  /// Values: "actionable_task", "grade_item", "grade_bucket",
  ///         "completed_work", "material", "dashboard_only", "unknown".
  final String itemType;

  /// Whether this item should be sent to the AI (Study Plan / Chatbot)
  /// as a task to schedule.
  final bool isActionableForAI;

  /// Whether this item is related to grades / scoring / results.
  final bool isGradeRelated;

  /// Whether this item exists only for dashboard / analytics display.
  final bool isDashboardOnly;

  /// How confident the classifier is (0.0–1.0).
  final double classificationConfidence;

  /// Human-readable reason for the classification decision.
  final String? classificationReason;

  /// Google Classroom workType if available (e.g. ASSIGNMENT, SHORT_ANSWER_QUESTION).
  final String? classroomWorkType;

  /// Google Classroom submission state if available (CREATED, TURNED_IN, RETURNED, etc.).
  final String? classroomSubmissionState;

  /// Whether Classroom marked the submission as late.
  final bool classroomLate;

  /// True when the task has a real schedulable deadline from Classroom or the user.
  final bool hasRealDeadline;

  /// Where the stored deadline came from: "classroom", "user", or "synthetic".
  final String? deadlineSource;

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
    this.source = 'unknown',
    this.itemType = 'unknown',
    this.isActionableForAI = true,
    this.isGradeRelated = false,
    this.isDashboardOnly = false,
    this.classificationConfidence = 0.0,
    this.classificationReason,
    this.classroomWorkType,
    this.classroomSubmissionState,
    this.classroomLate = false,
    this.hasRealDeadline = true,
    this.deadlineSource,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory Task.fromJson(Map<String, dynamic> json) {
    final parsedDeadline =
        DateTime.tryParse(json['deadline'] as String? ?? '') ?? DateTime.now();
    final source = json['source'] as String? ?? 'unknown';
    final hasRealDeadlineValue = json['hasRealDeadline'] as bool?;
    return Task(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      deadline: parsedDeadline,
      courseId: json['courseId'] as String? ?? '',
      courseName: json['courseName'] as String? ?? '',
      priority: _priorityFromString(json['priority'] as String?),
      status: _statusFromString(json['status'] as String?),
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'] as String)
          : null,
      estimatedMinutes: _intFromJson(json['estimatedMinutes']) ?? 30,
      scheduledTime: json['scheduledTime'] != null
          ? DateTime.tryParse(json['scheduledTime'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      assignedGrade: _doubleFromJson(json['assignedGrade']),
      maxPoints: _intFromJson(json['maxPoints']),
      // Classification fields — safe defaults for old data
      source: source,
      itemType: json['itemType'] as String? ?? 'unknown',
      isActionableForAI: json['isActionableForAI'] as bool? ?? true,
      isGradeRelated: json['isGradeRelated'] as bool? ?? false,
      isDashboardOnly: json['isDashboardOnly'] as bool? ?? false,
      classificationConfidence:
          _doubleFromJson(json['classificationConfidence']) ?? 0.0,
      classificationReason: json['classificationReason'] as String?,
      classroomWorkType: json['classroomWorkType'] as String?,
      classroomSubmissionState: json['classroomSubmissionState'] as String?,
      classroomLate: json['classroomLate'] as bool? ?? false,
      hasRealDeadline: hasRealDeadlineValue ??
          (source == 'google_classroom'
              ? !_looksSyntheticDeadline(parsedDeadline)
              : true),
      deadlineSource: json['deadlineSource'] as String? ??
          _defaultDeadlineSource(
            source: source,
            hasRealDeadline: hasRealDeadlineValue ??
                (source == 'google_classroom'
                    ? !_looksSyntheticDeadline(parsedDeadline)
                    : true),
          ),
    );
  }

  static bool _looksSyntheticDeadline(DateTime deadline) {
    final diff = deadline.difference(DateTime.now()).inMinutes;
    return (diff - const Duration(days: 7).inMinutes).abs() < 10;
  }

  static String _defaultDeadlineSource({
    required String source,
    required bool hasRealDeadline,
  }) {
    if (!hasRealDeadline) return 'synthetic';
    return source == 'google_classroom' ? 'classroom' : 'user';
  }

  static int? _intFromJson(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _doubleFromJson(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static TaskPriority _priorityFromString(String? s) {
    switch (s) {
      case 'urgent':
        return TaskPriority.urgent;
      case 'high':
        return TaskPriority.high;
      case 'low':
        return TaskPriority.low;
      default:
        return TaskPriority.medium;
    }
  }

  static TaskStatus _statusFromString(String? s) {
    switch (s) {
      case 'completed':
        return TaskStatus.completed;
      case 'inProgress':
        return TaskStatus.inProgress;
      case 'missed':
        return TaskStatus.missed;
      default:
        return TaskStatus.pending;
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
        // Classification metadata
        'source': source,
        'itemType': itemType,
        'isActionableForAI': isActionableForAI,
        'isGradeRelated': isGradeRelated,
        'isDashboardOnly': isDashboardOnly,
        'classificationConfidence': classificationConfidence,
        'classificationReason': classificationReason,
        'classroomWorkType': classroomWorkType,
        'classroomSubmissionState': classroomSubmissionState,
        'classroomLate': classroomLate,
        'hasRealDeadline': hasRealDeadline,
        'deadlineSource': deadlineSource,
      };

  Task copyWith({
    DateTime? deadline,
    TaskPriority? priority,
    TaskStatus? status,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? updatedAt,
    int? estimatedMinutes,
    // Classification overrides
    String? source,
    String? itemType,
    bool? isActionableForAI,
    bool? isGradeRelated,
    bool? isDashboardOnly,
    double? classificationConfidence,
    String? classificationReason,
    String? classroomWorkType,
    String? classroomSubmissionState,
    bool? classroomLate,
    bool? hasRealDeadline,
    String? deadlineSource,
  }) {
    return Task(
      id: id,
      title: title,
      description: description,
      deadline: deadline ?? this.deadline,
      courseId: courseId,
      courseName: courseName,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      scheduledTime: scheduledTime,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      updatedAt: updatedAt ?? this.updatedAt,
      assignedGrade: assignedGrade,
      maxPoints: maxPoints,
      source: source ?? this.source,
      itemType: itemType ?? this.itemType,
      isActionableForAI: isActionableForAI ?? this.isActionableForAI,
      isGradeRelated: isGradeRelated ?? this.isGradeRelated,
      isDashboardOnly: isDashboardOnly ?? this.isDashboardOnly,
      classificationConfidence:
          classificationConfidence ?? this.classificationConfidence,
      classificationReason: classificationReason ?? this.classificationReason,
      classroomWorkType: classroomWorkType ?? this.classroomWorkType,
      classroomSubmissionState:
          classroomSubmissionState ?? this.classroomSubmissionState,
      classroomLate: classroomLate ?? this.classroomLate,
      hasRealDeadline: hasRealDeadline ?? this.hasRealDeadline,
      deadlineSource: deadlineSource ?? this.deadlineSource,
    );
  }

  bool get isOverdue =>
      hasRealDeadline &&
      deadline.isBefore(DateTime.now()) &&
      status != TaskStatus.completed;

  /// True when the item has a real Classroom/user deadline still in the future.
  bool get hasUpcomingDeadline =>
      hasRealDeadline && !deadline.isBefore(DateTime.now());

  bool get isToday =>
      scheduledTime != null &&
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
