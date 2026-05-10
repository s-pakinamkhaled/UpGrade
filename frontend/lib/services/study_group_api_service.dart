import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/study_group.dart';
import 'api_service.dart';

class SuggestedMember {
  final String studentId;
  final String name;
  final int score;
  final List<String> reasons;

  const SuggestedMember({
    required this.studentId,
    required this.name,
    required this.score,
    required this.reasons,
  });

  factory SuggestedMember.fromJson(Map<String, dynamic> json) => SuggestedMember(
        studentId: json['studentId'] as String? ?? '',
        name: json['name'] as String? ?? 'Unknown',
        score: (json['score'] as num?)?.toInt() ?? 0,
        reasons: (json['reasons'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': studentId,
        'name': name,
        'courseIds': const <String>[],
        'assignments': const <Map<String, dynamic>>[],
        'studyGoals': const <String>[],
      };
}

class StudyGroupSuggestion {
  final String groupName;
  final String courseName;
  final String goal;
  final String relatedAssignmentOrTopic;
  final String suggestedMeetingTime;
  final String status;
  final List<SuggestedMember> suggestedMembers;

  const StudyGroupSuggestion({
    required this.groupName,
    required this.courseName,
    required this.goal,
    required this.relatedAssignmentOrTopic,
    required this.suggestedMeetingTime,
    required this.status,
    required this.suggestedMembers,
  });

  factory StudyGroupSuggestion.fromJson(Map<String, dynamic> json) =>
      StudyGroupSuggestion(
        groupName: json['groupName'] as String? ?? 'Study Group',
        courseName: json['courseName'] as String? ?? '',
        goal: json['goal'] as String? ?? '',
        relatedAssignmentOrTopic:
            json['relatedAssignmentOrTopic'] as String? ?? '',
        suggestedMeetingTime: json['suggestedMeetingTime'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        suggestedMembers: (json['suggestedMembers'] as List<dynamic>? ?? [])
            .map((e) => SuggestedMember.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class StudyGroupRequestPayload {
  final String creatorId;
  final String creatorName;
  final String courseId;
  final String courseName;
  final String? assignmentId;
  final String? assignmentTitle;
  final String? assignmentDeadline;
  final String? topic;
  final String goal;
  final DateTime preferredMeetingTime;
  final DateTime availableStart;
  final DateTime availableEnd;
  final int maxGroupSize;
  final String? riskLevel;
  final int? workloadScore;

  const StudyGroupRequestPayload({
    required this.creatorId,
    required this.creatorName,
    required this.courseId,
    required this.courseName,
    this.assignmentId,
    this.assignmentTitle,
    this.assignmentDeadline,
    this.topic,
    required this.goal,
    required this.preferredMeetingTime,
    required this.availableStart,
    required this.availableEnd,
    required this.maxGroupSize,
    this.riskLevel,
    this.workloadScore,
  });

  Map<String, dynamic> toJson() => {
        'creatorId': creatorId,
        'creatorName': creatorName,
        'courseId': courseId,
        'courseName': courseName,
        'assignmentId': assignmentId,
        'assignmentTitle': assignmentTitle,
        'assignmentDeadline': assignmentDeadline,
        'topic': topic,
        'goal': goal,
        'preferredMeetingTime': preferredMeetingTime.toIso8601String(),
        'availableStart': availableStart.toIso8601String(),
        'availableEnd': availableEnd.toIso8601String(),
        'maxGroupSize': maxGroupSize,
        'riskLevel': riskLevel,
        'workloadScore': workloadScore,
      };
}

class StudyGroupApiService {
  static String get _base => '${ApiService.baseUrl}/api/study-groups';

  static Future<StudyGroupSuggestion> getSuggestions(
    StudyGroupRequestPayload payload, {
    List<Map<String, dynamic>>? candidateStudents,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_base/suggestions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            ...payload.toJson(),
            if (candidateStudents != null) 'candidateStudents': candidateStudents,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      if (res.statusCode == 404) {
        throw Exception(
          'Study-group API not found. Restart backend to load new routes.',
        );
      }
      throw Exception('Failed to get suggestions: ${res.body}');
    }
    return StudyGroupSuggestion.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  static Future<StudyGroup> createGroup({
    required StudyGroupRequestPayload payload,
    required List<SuggestedMember> selectedMembers,
    List<Map<String, dynamic>>? candidateStudents,
  }) async {
    final body = payload.toJson()
      ..['selectedMemberIds'] = selectedMembers.map((m) => m.studentId).toList()
      ..['candidateStudents'] = candidateStudents;
    final res = await http
        .post(
          Uri.parse('$_base/create'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      if (res.statusCode == 404) {
        throw Exception(
          'Study-group API not found. Restart backend to load new routes.',
        );
      }
      throw Exception(_extractError(res.body));
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return StudyGroup.fromJson(decoded['group'] as Map<String, dynamic>);
  }

  static Future<List<StudyGroup>> getMyGroups(String userId) async {
    final uri = Uri.parse('$_base/my-groups')
        .replace(queryParameters: {'userId': userId});
    final res = await http
        .get(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      if (res.statusCode == 404) {
        // Backend still running old build; show empty state instead of breaking UI.
        return [];
      }
      throw Exception('Failed to fetch groups: ${res.body}');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final groups = decoded['groups'] as List<dynamic>? ?? [];
    return groups
        .map((e) => StudyGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<StudyGroup> updateGroupStatus({
    required String groupId,
    required StudyGroupStatus status,
  }) async {
    final res = await http
        .patch(
          Uri.parse('$_base/$groupId/status'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'status': status.name}),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body));
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return StudyGroup.fromJson(decoded['group'] as Map<String, dynamic>);
  }

  static String _extractError(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final detail = decoded['detail'];
      if (detail is String) return detail;
    } catch (_) {}
    return 'Request failed';
  }
}
