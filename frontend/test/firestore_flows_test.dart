import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrade/models/classroom_course.dart';
import 'package:upgrade/models/task.dart';
import 'package:upgrade/services/user_matching_profile_sync_service.dart';

void main() {
  group('Firestore profile sync flow (fake_cloud_firestore)', () {
    late FakeFirebaseFirestore firestore;
    late MockUser user;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      firestore = FakeFirebaseFirestore();
      user = MockUser(
        uid: 'student_001',
        email: 'pakinam@test.com',
        displayName: 'Pakinam Ahmed',
      );
    });

    test('writes merged user profile with courseIds and assignments', () async {
      final courses = [
        const ClassroomCourse(id: 'cs101', name: 'Database'),
      ];
      final tasks = [
        Task(
          id: 'task_1',
          title: 'Normalization HW',
          deadline: DateTime.now().add(const Duration(days: 2)),
          courseId: 'cs101',
          courseName: 'Database',
          estimatedMinutes: 60,
        ),
      ];

      await UserMatchingProfileSyncService.syncCurrentUserProfile(
        courses: courses,
        tasks: tasks,
        firestore: firestore,
        authUser: user,
      );

      final doc = await firestore.collection('users').doc('student_001').get();
      final data = doc.data()!;

      expect(data['uid'], 'student_001');
      expect(data['email'], 'pakinam@test.com');
      expect(data['courseIds'], ['cs101']);
      expect(data['assignments'], isA<List>());
      expect((data['assignments'] as List).length, 1);
      expect(data['riskLevel'], isA<String>());
      expect(data['workloadScore'], isA<int>());
    });

    test('does not overwrite unrelated user fields on merge sync', () async {
      await firestore.collection('users').doc('student_001').set({
        'uid': 'student_001',
        'legacyFlag': true,
      });

      await UserMatchingProfileSyncService.syncCurrentUserProfile(
        courses: const [],
        tasks: const [],
        firestore: firestore,
        authUser: user,
      );

      final data = (await firestore.collection('users').doc('student_001').get())
          .data()!;

      expect(data['legacyFlag'], isTrue);
      expect(data['email'], 'pakinam@test.com');
    });

    test('skips sync when auth user is null', () async {
      await UserMatchingProfileSyncService.syncCurrentUserProfile(
        courses: const [],
        tasks: const [],
        firestore: firestore,
        resolveAuthFromFirebase: false,
      );

      final snapshot = await firestore.collection('users').get();
      expect(snapshot.docs, isEmpty);
    });
  });

  group('Firestore pairing flow (fake_cloud_firestore)', () {
    test('marks pairing session as paired without exposing secrets', () async {
      final firestore = FakeFirebaseFirestore();

      await firestore.collection('pairing_sessions').doc('session_abc').set({
        'paired': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await firestore.collection('pairing_sessions').doc('session_abc').update({
        'paired': true,
        'device': 'Mobile device',
      });

      final doc =
          await firestore.collection('pairing_sessions').doc('session_abc').get();

      expect(doc.data()!['paired'], isTrue);
      expect(doc.data()!['device'], 'Mobile device');
      expect(doc.data()!.containsKey('password'), isFalse);
    });
  });

  group('Firestore study-group matching data (fake_cloud_firestore)', () {
    test('finds classmates by courseIds without exposing other users emails in query', () async {
      final firestore = FakeFirebaseFirestore();

      await firestore.collection('users').doc('student_001').set({
        'courseIds': ['cs101'],
        'email': 'me@test.com',
      });
      await firestore.collection('users').doc('student_002').set({
        'courseIds': ['cs101'],
        'email': 'peer@test.com',
        'name': 'Peer Student',
      });
      await firestore.collection('users').doc('student_003').set({
        'courseIds': ['cs999'],
        'email': 'other@test.com',
      });

      final enrolled = await firestore
          .collection('users')
          .where('courseIds', arrayContains: 'cs101')
          .get();

      final peerIds = enrolled.docs
          .map((doc) => doc.id)
          .where((id) => id != 'student_001')
          .toList();

      expect(peerIds, ['student_002']);
      expect(peerIds, isNot(contains('student_003')));
    });
  });
}
