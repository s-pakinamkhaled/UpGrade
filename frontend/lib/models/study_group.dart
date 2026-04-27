class StudyGroup {
  final String id;
  final String courseId;
  final String courseName;
  final List<GroupMember> members;
  final List<GroupMessage> messages;
  final DateTime createdAt;
  final bool isActive;
  
  StudyGroup({
    required this.id,
    required this.courseId,
    required this.courseName,
    this.members = const [],
    this.messages = const [],
    required this.createdAt,
    this.isActive = true,
  });
}

class GroupMember {
  final String id;
  final String name;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastSeen;
  
  GroupMember({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isOnline = false,
    this.lastSeen,
  });
}

class GroupMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  
  GroupMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.isRead = false,
  });
}
