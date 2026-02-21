class FocusSession {
  final String id;
  final String taskId;
  final DateTime startTime;
  final DateTime? endTime;
  final int focusLevel; // 1-10
  final bool isCompleted;
  
  FocusSession({
    required this.id,
    required this.taskId,
    required this.startTime,
    this.endTime,
    this.focusLevel = 5,
    this.isCompleted = false,
  });
  
  Duration? get duration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    return null;
  }
}
