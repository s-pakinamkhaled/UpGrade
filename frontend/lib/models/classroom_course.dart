/// Model for Google Classroom Course (from API).
class ClassroomCourse {
  final String id;
  final String name;
  final String? section;
  final String? description;

  const ClassroomCourse({
    required this.id,
    required this.name,
    this.section,
    this.description,
  });

  factory ClassroomCourse.fromJson(Map<String, dynamic> json) {
    return ClassroomCourse(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed course',
      section: json['section'] as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'section': section,
        'description': description,
      };
}
