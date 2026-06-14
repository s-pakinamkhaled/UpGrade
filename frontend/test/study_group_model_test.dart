import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/models/classroom_submission.dart';
import 'package:upgrade/models/study_group.dart';

void main() {
  group('ClassroomSubmission', () {
    test('fromJson parses returned graded submission', () {
      final submission = ClassroomSubmission.fromJson({
        'id': 'sub_1',
        'courseId': 'course_1',
        'courseWorkId': 'a1',
        'state': 'RETURNED',
        'assignedGrade': 18,
        'updateTime': '2026-06-01T12:00:00.000Z',
      });

      expect(submission.isSubmitted, isTrue);
      expect(submission.isReturned, isTrue);
      expect(submission.displayGrade, 18);
      expect(submission.completedAt, isNotNull);
    });

    test('empty submission is not submitted', () {
      final submission = ClassroomSubmission.empty();

      expect(submission.isSubmitted, isFalse);
      expect(submission.completedAt, isNull);
    });
  });

  group('StudyGroup model', () {
    test('fromJson and toJson round-trip', () {
      final json = {
        'groupId': 'g1',
        'creatorId': 'u1',
        'courseId': 'cs101',
        'courseName': 'Database',
        'goal': 'Finish project',
        'members': [
          {'userId': 'u1', 'name': 'Pakinam', 'matchScore': 90},
        ],
        'invitedUsers': ['u2'],
        'maxGroupSize': 4,
        'meetingTime': '2026-06-01T18:00:00.000',
        'availableStart': '2026-06-01T18:00:00.000',
        'availableEnd': '2026-06-01T21:00:00.000',
        'status': 'pending',
        'createdAt': '2026-06-01T10:00:00.000',
        'updatedAt': '2026-06-01T10:00:00.000',
        'groupName': 'Database Normalization Group',
        'relatedAssignmentOrTopic': 'Normalization',
      };

      final group = StudyGroup.fromJson(json);
      final encoded = group.toJson();

      expect(group.groupId, 'g1');
      expect(group.members.first.name, 'Pakinam');
      expect(group.status, StudyGroupStatus.pending);
      expect(encoded['courseName'], 'Database');
    });
  });

  group('StudyGoalExtension', () {
    test('labels are human readable', () {
      expect(StudyGoal.examPreparation.label, 'Exam preparation');
      expect(StudyGoal.generalStudySession.label, 'General study session');
    });
  });
}
