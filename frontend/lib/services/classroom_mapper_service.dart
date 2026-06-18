import '../models/classroom_course.dart';
import '../models/classroom_assignment.dart';
import '../models/classroom_submission.dart';
import '../models/task.dart';
import 'classroom_item_classifier_service.dart';

/// Result object returned after mapping all classroom data
class ClassroomMappedResult {
  final List<ClassroomCourse> courses;
  final List<ClassroomAssignment> assignments;
  final List<ClassroomSubmission> submissions;
  final List<Task> tasks;

  ClassroomMappedResult({
    required this.courses,
    required this.assignments,
    required this.submissions,
    required this.tasks,
  });
}

class ClassroomMapperService {
  /// 🔹 Map ALL classroom data (used by Provider)
  static ClassroomMappedResult mapAll({
    required List<ClassroomCourse> courses,
    required List<ClassroomAssignment> assignments,
    required List<ClassroomSubmission> submissions,
  }) {
    final List<Task> allTasks = [];

    for (final course in courses) {
      final courseAssignments =
          assignments.where((a) => a.courseId == course.id).toList();

      final courseSubmissions =
          submissions.where((s) => s.courseId == course.id).toList();

      allTasks.addAll(
        mapToTasks(
          course: course,
          assignments: courseAssignments,
          submissions: courseSubmissions,
        ),
      );
    }

    // Classify all tasks before returning
    final classifiedTasks =
        ClassroomItemClassifierService.classifyAll(allTasks);

    return ClassroomMappedResult(
      courses: courses,
      assignments: assignments,
      submissions: submissions,
      tasks: classifiedTasks,
    );
  }

  /// 🔹 Convert Google Classroom data into app Tasks (with grades and status)
  static List<Task> mapToTasks({
    required ClassroomCourse course,
    required List<ClassroomAssignment> assignments,
    required List<ClassroomSubmission> submissions,
  }) {
    final List<Task> tasks = [];

    for (final assignment in assignments) {
      final sub = submissions
              .cast<ClassroomSubmission>()
              .where((s) => s.assignmentId == assignment.id)
              .fold<ClassroomSubmission?>(
                null,
                (prev, s) => prev ?? s,
              ) ??
          ClassroomSubmission.empty();

      final hasRealDeadline = assignment.dueDate != null;
      final now = DateTime.now();
      final deadline = assignment.dueDate ?? now.add(const Duration(days: 7));

      final estimatedMinutes = _estimateTime(assignment.maxPoints);

      final taskStatus = sub.isReturned || sub.isSubmitted
          ? TaskStatus.completed
          : (hasRealDeadline && deadline.isBefore(now)
              ? TaskStatus.missed
              : TaskStatus.pending);

      final priority = _calculatePriority(
        deadline: deadline,
        status: taskStatus,
        isSubmitted: sub.isSubmitted,
        hasRealDeadline: hasRealDeadline,
      );

      tasks.add(
        Task(
          id: assignment.id,
          title: assignment.title,
          description: assignment.description,
          deadline: deadline,
          courseId: course.id,
          courseName: course.name,
          priority: priority,
          status: taskStatus,
          estimatedMinutes: estimatedMinutes,
          completedAt: sub.completedAt,
          assignedGrade: sub.displayGrade,
          maxPoints: assignment.maxPoints,
          source: 'google_classroom',
          classroomWorkType: assignment.workType,
          classroomSubmissionState: sub.state,
          classroomLate: sub.late,
          hasRealDeadline: hasRealDeadline,
          deadlineSource: hasRealDeadline ? 'classroom' : 'synthetic',
        ),
      );
    }

    return tasks;
  }

  /// Raw response from ClassroomSyncService: data = [ { course, works, submissions }, ... ]
  static ({List<ClassroomCourse> courses, List<Task> tasks}) mapFromRawResponse(
    Map<String, dynamic> raw,
  ) {
    final courses = <ClassroomCourse>[];
    final tasks = <Task>[];

    final data = raw['data'] as List<dynamic>? ?? [];
    for (final item in data) {
      final map = item as Map<String, dynamic>;
      final course =
          ClassroomCourse.fromJson(map['course'] as Map<String, dynamic>);

      final works = map['works'] as List<dynamic>? ?? [];
      final subs = map['submissions'] as List<dynamic>? ?? [];

      final assignments = works
          .map((a) => ClassroomAssignment.fromJson(a as Map<String, dynamic>))
          .toList();
      final submissions = subs
          .map((s) => ClassroomSubmission.fromJson(s as Map<String, dynamic>))
          .toList();

      courses.add(course);
      tasks.addAll(
        mapToTasks(
          course: course,
          assignments: assignments,
          submissions: submissions,
        ),
      );
    }

    // Classify all mapped tasks
    final classifiedTasks = ClassroomItemClassifierService.classifyAll(tasks);
    return (courses: courses, tasks: classifiedTasks);
  }

  /// Priority reflects how soon a deadline is — not how long ago it passed.
  static TaskPriority _calculatePriority({
    required DateTime? deadline,
    required TaskStatus status,
    required bool isSubmitted,
    required bool hasRealDeadline,
  }) {
    if (isSubmitted) return TaskPriority.low;

    if (status == TaskStatus.missed) return TaskPriority.low;

    if (deadline == null || !hasRealDeadline) return TaskPriority.low;

    final hoursLeft = deadline.difference(DateTime.now()).inHours;

    if (hoursLeft < 0) return TaskPriority.low;
    if (hoursLeft <= 24) return TaskPriority.urgent;
    if (hoursLeft <= 72) return TaskPriority.high;
    if (hoursLeft <= 7 * 24) return TaskPriority.medium;

    return TaskPriority.low;
  }

  /// 🔹 Simple heuristic for effort estimation
  static int _estimateTime(int? maxPoints) {
    if (maxPoints == null) return 30;

    if (maxPoints <= 20) return 30;
    if (maxPoints <= 50) return 60;

    return 90;
  }
}
