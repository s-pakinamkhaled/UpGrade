import 'package:upgrade/models/task.dart';

Task makeTask({
  String id = 'task_1',
  String title = 'Sample Task',
  String courseId = 'course_1',
  String courseName = 'Database',
  TaskStatus status = TaskStatus.pending,
  TaskPriority priority = TaskPriority.medium,
  DateTime? deadline,
  DateTime? completedAt,
  int estimatedMinutes = 60,
  double? assignedGrade,
  int? maxPoints,
}) {
  final now = DateTime.now();
  return Task(
    id: id,
    title: title,
    deadline: deadline ?? now.add(const Duration(days: 2)),
    courseId: courseId,
    courseName: courseName,
    priority: priority,
    status: status,
    estimatedMinutes: estimatedMinutes,
    completedAt: completedAt,
    assignedGrade: assignedGrade,
    maxPoints: maxPoints,
  );
}
