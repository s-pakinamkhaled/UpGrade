/// Model for Google Classroom CourseWork (assignment) from API.
/// dueDate: { year, month, day }, dueTime: { hours, minutes } in UTC.
class ClassroomAssignment {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final int? maxPoints;
  final String? workType;

  const ClassroomAssignment({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    this.dueDate,
    this.maxPoints,
    this.workType,
  });

  factory ClassroomAssignment.fromJson(Map<String, dynamic> json) {
    DateTime? due;
    final dueDate = json['dueDate'] as Map<String, dynamic>?;
    final dueTime = json['dueTime'] as Map<String, dynamic>?;
    // Classroom API returns dueDate/dueTime in UTC; parse as UTC then convert to local
    // so the correct calendar day shows for the user's timezone.
    if (dueDate != null &&
        dueDate['year'] != null &&
        dueDate['month'] != null &&
        dueDate['day'] != null) {
      final y = dueDate['year'] as int;
      final m = dueDate['month'] as int;
      final d = dueDate['day'] as int;
      int hour = 23, minute = 59;
      if (dueTime != null) {
        hour = dueTime['hours'] as int? ?? 23;
        minute = dueTime['minutes'] as int? ?? 59;
      }
      due = DateTime.utc(y, m, d, hour, minute).toLocal();
    }
    return ClassroomAssignment(
      id: json['id'] as String? ?? '',
      courseId: json['courseId'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      dueDate: due,
      maxPoints: json['maxPoints'] != null
          ? (json['maxPoints'] is int
              ? json['maxPoints'] as int
              : (json['maxPoints'] as num).toInt())
          : null,
      workType: json['workType'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseId': courseId,
        'title': title,
        'description': description,
        'dueDate': dueDate?.toIso8601String(),
        'maxPoints': maxPoints,
        'workType': workType,
      };
}
