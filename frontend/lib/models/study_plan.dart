/// A single item in an AI-generated study plan.
class StudyPlanItem {
  final String? taskId;
  final String taskTitle;
  final String courseName;
  final String? deadline;
  final String? status;
  final String suggestedDate; // YYYY-MM-DD
  final String suggestedTime; // e.g. "14:00 – 16:00"
  final double hoursNeeded;
  final String priority;
  final String tip;

  const StudyPlanItem({
    this.taskId,
    required this.taskTitle,
    required this.courseName,
    this.deadline,
    this.status,
    required this.suggestedDate,
    required this.suggestedTime,
    required this.hoursNeeded,
    required this.priority,
    required this.tip,
  });

  factory StudyPlanItem.fromJson(Map<String, dynamic> json) {
    return StudyPlanItem(
      taskId: json['taskId'] as String?,
      taskTitle: json['taskTitle'] as String? ?? '',
      courseName: json['courseName'] as String? ?? '',
      deadline: json['deadline'] as String?,
      status: json['status'] as String?,
      suggestedDate: json['suggestedDate'] as String? ?? '',
      suggestedTime: json['suggestedTime'] as String? ?? '',
      hoursNeeded: (json['hoursNeeded'] as num?)?.toDouble() ?? 1.0,
      priority: json['priority'] as String? ?? 'medium',
      tip: json['tip'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'taskTitle': taskTitle,
        'courseName': courseName,
        'deadline': deadline,
        'status': status,
        'suggestedDate': suggestedDate,
        'suggestedTime': suggestedTime,
        'hoursNeeded': hoursNeeded,
        'priority': priority,
        'tip': tip,
      };
}

/// Full study plan returned by the backend.
class StudyPlan {
  final bool success;
  final String studentName;
  final String generatedAt;
  final List<StudyPlanItem> items;
  final String summary;

  const StudyPlan({
    required this.success,
    required this.studentName,
    required this.generatedAt,
    required this.items,
    required this.summary,
  });

  factory StudyPlan.fromJson(Map<String, dynamic> json) {
    return StudyPlan(
      success: json['success'] as bool? ?? false,
      studentName: json['studentName'] as String? ?? '',
      generatedAt: json['generatedAt'] as String? ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => StudyPlanItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      summary: json['summary'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        'studentName': studentName,
        'generatedAt': generatedAt,
        'items': items.map((e) => e.toJson()).toList(),
        'summary': summary,
      };
}
