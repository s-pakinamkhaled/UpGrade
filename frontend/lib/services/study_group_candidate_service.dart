import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudyGroupCandidateService {
  static Future<List<Map<String, dynamic>>> loadCandidatesFromFirestore({
    required String selectedCourseId,
    required DateTime requestedAvailableStart,
    required DateTime requestedAvailableEnd,
    required String selectedGoal,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final snapshot = await FirebaseFirestore.instance.collection('users').get();

    return snapshot.docs
        .where((doc) => doc.id != currentUserId)
        .map((doc) => _mapDocToCandidate(
              doc: doc,
              selectedCourseId: selectedCourseId,
              requestedAvailableStart: requestedAvailableStart,
              requestedAvailableEnd: requestedAvailableEnd,
              selectedGoal: selectedGoal,
            ))
        .toList();
  }

  static Map<String, dynamic> _mapDocToCandidate({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required String selectedCourseId,
    required DateTime requestedAvailableStart,
    required DateTime requestedAvailableEnd,
    required String selectedGoal,
  }) {
    final data = doc.data();
    final rawCourseIds = data['courseIds'];
    final rawCourses = data['courses'];
    final fromCourseIds = (rawCourseIds is List)
        ? rawCourseIds.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final fromCourses = (rawCourses is List)
        ? rawCourses
            .map((e) {
              if (e is Map<String, dynamic>) return e['id']?.toString() ?? '';
              if (e is Map) return e['id']?.toString() ?? '';
              return '';
            })
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];
    final mergedCourseIds = {...fromCourseIds, ...fromCourses}.toList();

    final assignments = _extractAssignments(data);
    final availability = _extractAvailability(
      data: data,
      defaultStart: requestedAvailableStart,
      defaultEnd: requestedAvailableEnd,
    );
    final goals = _extractStudyGoals(data, selectedGoal);

    return {
      'id': doc.id,
      'name': (data['name'] as String?) ??
          (data['displayName'] as String?) ??
          (data['email'] as String?) ??
          'Student',
      'courseIds': mergedCourseIds,
      'assignments': assignments,
      'studyGoals': goals,
      'availableStart': availability.$1,
      'availableEnd': availability.$2,
      'riskLevel': (data['riskLevel'] as String?)?.toLowerCase(),
      'workloadScore': _toInt(data['workloadScore']),
    };
  }

  static List<Map<String, dynamic>> _extractAssignments(
    Map<String, dynamic> data,
  ) {
    final raw = data['assignments'];
    if (raw is List) {
      return raw
          .map((e) {
            if (e is Map<String, dynamic>) {
              return {
                'assignmentId': e['assignmentId']?.toString(),
                'deadline': e['deadline']?.toString(),
              };
            }
            if (e is Map) {
              return {
                'assignmentId': e['assignmentId']?.toString(),
                'deadline': e['deadline']?.toString(),
              };
            }
            return <String, dynamic>{};
          })
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [];
  }

  static (String, String) _extractAvailability({
    required Map<String, dynamic> data,
    required DateTime defaultStart,
    required DateTime defaultEnd,
  }) {
    final availability = data['availability'];
    String? start;
    String? end;

    if (availability is Map<String, dynamic>) {
      start = availability['start']?.toString();
      end = availability['end']?.toString();
    } else if (availability is Map) {
      start = availability['start']?.toString();
      end = availability['end']?.toString();
    }

    start ??= data['availableStart']?.toString();
    end ??= data['availableEnd']?.toString();
    start ??= defaultStart.toIso8601String();
    end ??= defaultEnd.toIso8601String();
    return (start, end);
  }

  static List<String> _extractStudyGoals(
    Map<String, dynamic> data,
    String fallbackGoal,
  ) {
    final raw = data['studyGoals'];
    if (raw is List) {
      final goals = raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      if (goals.isNotEmpty) return goals;
    }
    return [fallbackGoal];
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
