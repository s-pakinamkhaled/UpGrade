class Course {
  final String id;
  final String name;
  final String? code;
  final String? instructor;
  final List<DateTime> deadlines;
  final List<String> preferredStudyTimes;
  
  Course({
    required this.id,
    required this.name,
    this.code,
    this.instructor,
    this.deadlines = const [],
    this.preferredStudyTimes = const [],
  });
}
