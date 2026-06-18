import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final int? missedCount;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.missedCount,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'system',
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String userId,
  }) {
    final data = doc.data() ?? {};
    final rawCreatedAt = data['createdAt'];
    final DateTime createdAt;
    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    return AppNotification(
      id: doc.id,
      userId: userId,
      title: (data['title'] as String?) ?? '',
      message: (data['message'] as String?) ?? '',
      type: (data['type'] as String?) ?? 'system',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: createdAt,
      missedCount: (data['missedCount'] as num?)?.toInt(),
    );
  }

  static const manualTestTitle = 'Firebase notification test';

  bool get isMissedSummary => type == 'missed_summary';

  bool get isManualTest => title == manualTestTitle;

  bool get isListItem => !isMissedSummary && !isManualTest;

  AppNotification copyWith({bool? isRead, int? missedCount}) {
    return AppNotification(
      id: id,
      userId: userId,
      title: title,
      message: message,
      type: type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      missedCount: missedCount ?? this.missedCount,
    );
  }
}
