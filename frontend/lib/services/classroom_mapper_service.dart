import '../models/classroom_course.dart';
import '../models/classroom_assignment.dart';
import '../models/classroom_submission.dart';
import '../models/task.dart';

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

    return ClassroomMappedResult(
      courses: courses,
      assignments: assignments,
      submissions: submissions,
      tasks: allTasks,
    );
  }

  /// 🔹 Convert Google Classroom data into app Tasks
  static List<Task> mapToTasks({
    required ClassroomCourse course,
    required List<ClassroomAssignment> assignments,
    required List<ClassroomSubmission> submissions,
  }) {
    final List<Task> tasks = [];

    for (final assignment in assignments) {
      final submission = submissions.firstWhere(
        (s) => s.assignmentId == assignment.id,
        orElse: () => ClassroomSubmission.empty(),
      );

      final deadline = assignment.dueDate;

      final priority = _calculatePriority(
        deadline: deadline,
        isSubmitted: submission.isSubmitted,
      );

      final estimatedMinutes =
          _estimateTime(assignment.maxPoints);

      tasks.add(
        Task(
          id: assignment.id,
          title: assignment.title,
          description: assignment.description,
          deadline: deadline,
          courseId: course.id,
          courseName: course.name,
          priority: priority,
          estimatedMinutes: estimatedMinutes,
        ),
      );
    }

    return tasks;
  }
  static ({List<ClassroomCourse> courses, List<Task> tasks})
    mapFromRawResponse(Map<String, dynamic> raw) {
  final courses = <ClassroomCourse>[];
  final tasks = <Task>[];

  for (final item in raw['data']) {
    final course = ClassroomCourse.fromJson(item['course']);

    final assignments = (item['works'] as List)
        .map((a) => ClassroomAssignment.fromJson(a))
        .toList();

    final submissions = (item['submissions'] as List)
        .map((s) => ClassroomSubmission.fromJson(s))
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

  return (courses: courses, tasks: tasks);
}


  /// 🔹 AI-ish priority logic (important)
  static TaskPriority _calculatePriority({
    required DateTime? deadline,
    required bool isSubmitted,
  }) {
    if (isSubmitted) return TaskPriority.low;

    if (deadline == null) return TaskPriority.medium;

    final hoursLeft = deadline.difference(DateTime.now()).inHours;

    if (hoursLeft <= 24) return TaskPriority.high;
    if (hoursLeft <= 72) return TaskPriority.medium;

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
