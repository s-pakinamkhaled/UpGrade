enum StudyGoal {
  assignmentSolving,
  quizRevision,
  examPreparation,
  generalStudySession,
}

extension StudyGoalExtension on StudyGoal {
  String get label {
    switch (this) {
      case StudyGoal.assignmentSolving:
        return 'Assignment solving';
      case StudyGoal.quizRevision:
        return 'Quiz revision';
      case StudyGoal.examPreparation:
        return 'Exam preparation';
      case StudyGoal.generalStudySession:
        return 'General study session';
    }
  }
}

enum StudyGroupStatus { pending, active, completed }

class GroupMember {
  final String userId;
  final String name;
  final int? matchScore;

  const GroupMember({
    required this.userId,
    required this.name,
    this.matchScore,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
        userId: json['userId'] as String? ?? '',
        name: json['name'] as String? ?? 'Unknown',
        matchScore: (json['matchScore'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'matchScore': matchScore,
      };
}

class StudyGroup {
  final String groupId;
  final String creatorId;
  final String courseId;
  final String courseName;
  final String? assignmentId;
  final String? topic;
  final String goal;
  final List<GroupMember> members;
  final List<String> invitedUsers;
  final int maxGroupSize;
  final DateTime meetingTime;
  final DateTime availableStart;
  final DateTime availableEnd;
  final StudyGroupStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String groupName;
  final String relatedAssignmentOrTopic;

  const StudyGroup({
    required this.groupId,
    required this.creatorId,
    required this.courseId,
    required this.courseName,
    this.assignmentId,
    this.topic,
    required this.goal,
    required this.members,
    required this.invitedUsers,
    required this.maxGroupSize,
    required this.meetingTime,
    required this.availableStart,
    required this.availableEnd,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.groupName,
    required this.relatedAssignmentOrTopic,
  });

  factory StudyGroup.fromJson(Map<String, dynamic> json) => StudyGroup(
        groupId: json['groupId'] as String? ?? '',
        creatorId: json['creatorId'] as String? ?? '',
        courseId: json['courseId'] as String? ?? '',
        courseName: json['courseName'] as String? ?? '',
        assignmentId: json['assignmentId'] as String?,
        topic: json['topic'] as String?,
        goal: json['goal'] as String? ?? 'General study session',
        members: (json['members'] as List<dynamic>? ?? [])
            .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
            .toList(),
        invitedUsers: (json['invitedUsers'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        maxGroupSize: (json['maxGroupSize'] as num?)?.toInt() ?? 4,
        meetingTime: DateTime.tryParse(json['meetingTime'] as String? ?? '') ??
            DateTime.now(),
        availableStart:
            DateTime.tryParse(json['availableStart'] as String? ?? '') ??
                DateTime.now(),
        availableEnd: DateTime.tryParse(json['availableEnd'] as String? ?? '') ??
            DateTime.now(),
        status: _statusFromString(json['status'] as String?),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
        groupName: json['groupName'] as String? ?? 'Study Group',
        relatedAssignmentOrTopic:
            json['relatedAssignmentOrTopic'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'creatorId': creatorId,
        'courseId': courseId,
        'courseName': courseName,
        'assignmentId': assignmentId,
        'topic': topic,
        'goal': goal,
        'members': members.map((e) => e.toJson()).toList(),
        'invitedUsers': invitedUsers,
        'maxGroupSize': maxGroupSize,
        'meetingTime': meetingTime.toIso8601String(),
        'availableStart': availableStart.toIso8601String(),
        'availableEnd': availableEnd.toIso8601String(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'groupName': groupName,
        'relatedAssignmentOrTopic': relatedAssignmentOrTopic,
      };

  static StudyGroupStatus _statusFromString(String? raw) {
    switch (raw) {
      case 'active':
        return StudyGroupStatus.active;
      case 'completed':
        return StudyGroupStatus.completed;
      default:
        return StudyGroupStatus.pending;
    }
  }
}
