/// Model for Google Classroom StudentSubmission from API.
/// state: CREATED, NEW, TURNED_IN, RETURNED, RECLAIMED_BY_STUDENT.
/// RETURNED = teacher returned with grade; TURNED_IN = submitted, awaiting grade.
class ClassroomSubmission {
  final String id;
  final String courseId;
  final String assignmentId;
  final String state; // TURNED_IN, RETURNED, etc.
  final double? assignedGrade;
  final double? draftGrade;
  final DateTime? updateTime;
  final bool late;

  const ClassroomSubmission({
    required this.id,
    required this.courseId,
    required this.assignmentId,
    required this.state,
    this.assignedGrade,
    this.draftGrade,
    this.updateTime,
    this.late = false,
  });

  bool get isSubmitted =>
      state == 'TURNED_IN' ||
      state == 'RETURNED' ||
      state == 'RECLAIMED_BY_STUDENT';
  bool get isReturned => state == 'RETURNED';
  double? get displayGrade => assignedGrade ?? draftGrade;
  DateTime? get completedAt => isSubmitted ? updateTime : null;

  factory ClassroomSubmission.fromJson(Map<String, dynamic> json) {
    double? ag, dg;
    DateTime? update;
    if (json['assignedGrade'] != null) {
      ag = (json['assignedGrade'] is num)
          ? (json['assignedGrade'] as num).toDouble()
          : null;
    }
    if (json['draftGrade'] != null) {
      dg = (json['draftGrade'] is num)
          ? (json['draftGrade'] as num).toDouble()
          : null;
    }
    if (json['updateTime'] is String) {
      update = DateTime.tryParse(json['updateTime'] as String)?.toLocal();
    }

    return ClassroomSubmission(
      id: json['id'] as String? ?? '',
      courseId: json['courseId'] as String? ?? '',
      assignmentId: json['courseWorkId'] as String? ??
          json['assignmentId'] as String? ??
          '',
      state: json['state'] as String? ?? 'CREATED',
      assignedGrade: ag,
      draftGrade: dg,
      updateTime: update,
      late: json['late'] as bool? ?? false,
    );
  }

  factory ClassroomSubmission.empty() => ClassroomSubmission(
        id: '',
        courseId: '',
        assignmentId: '',
        state: 'CREATED',
        updateTime: null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseId': courseId,
        'courseWorkId': assignmentId,
        'state': state,
        'assignedGrade': assignedGrade,
        'draftGrade': draftGrade,
        'updateTime': updateTime?.toIso8601String(),
        'late': late,
      };
}
