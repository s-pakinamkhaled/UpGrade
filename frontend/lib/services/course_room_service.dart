import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';

class AcceptRequestResult {
  final String requestId;
  final String groupId;
  final String roomId;

  const AcceptRequestResult({
    required this.requestId,
    required this.groupId,
    required this.roomId,
  });
}

class CourseRoomService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static void _logFirestoreOp(String operation, String path) {
    if (!kDebugMode) return;
    debugPrint('[CourseRoom][Firestore][$operation] path=$path');
  }

  static Future<int> sendCourseRoomRequest({
    required String courseId,
    required String courseName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Please log in first.');

    if (kDebugMode) {
      debugPrint(
        '[CourseRoom] match by courseIds arrayContains (not email). '
        'selectedCourseId=$courseId',
      );
    }

    final usersPath = _db.collection('users').path;
    _logFirestoreOp('READ_QUERY', usersPath);
    final enrolled = await _db
        .collection('users')
        .where('courseIds', arrayContains: courseId)
        .get();

    if (kDebugMode) {
      debugPrint(
        '[CourseRoom] users with this course in courseIds: '
        'fetchedCount=${enrolled.docs.length}',
      );
      for (final doc in enrolled.docs) {
        final Map<String, dynamic> data = doc.data();
        final ids = data['courseIds'];
        final list = ids is List
            ? ids.map((e) => e.toString()).toList()
            : <String>[];
        debugPrint(
          '[CourseRoom]   userId=${doc.id} courseIds=$list',
        );
      }
    }

    final invitedDocs = enrolled.docs.where((doc) => doc.id != user.uid).toList();
    final invitedUserIds = invitedDocs.map((doc) => doc.id).toList();

    if (kDebugMode) {
      debugPrint(
        '[CourseRoom] matchedClassmates (excluding self): ${invitedUserIds.length}',
      );
    }
    final invitedEmails = invitedDocs
        .map((doc) => (doc.data()['email'] as String?) ?? '')
        .where((email) => email.trim().contains('@'))
        .toSet()
        .toList();

    if (invitedUserIds.isEmpty) {
      throw Exception('No enrolled classmates found for this course.');
    }

    final creatorName = user.displayName ?? user.email ?? 'Student';
    final groupStudiesPath = _db.collection('groupStudies').path;
    _logFirestoreOp('WRITE_ADD', groupStudiesPath);
    final groupRef = await _db.collection('groupStudies').add({
      'courseId': courseId,
      'courseName': courseName,
      'createdBy': user.uid,
      'createdByName': creatorName,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'memberIds': [user.uid],
      'memberNames': {user.uid: creatorName},
      'active': true,
    });

    final batch = _db.batch();
    _logFirestoreOp('WRITE_BATCH_START', _db.collection('groupStudyRequests').path);
    for (final doc in invitedDocs) {
      final Map<String, dynamic> data = doc.data();
      final toEmail = (data['email'] as String?) ?? '';
      final reqRef = _db.collection('groupStudyRequests').doc();
      _logFirestoreOp('WRITE_BATCH_SET', reqRef.path);
      batch.set(reqRef, {
        'groupId': groupRef.id,
        'courseId': courseId,
        'courseName': courseName,
        'fromUserId': user.uid,
        'fromUserName': creatorName,
        'toUserId': doc.id,
        'toEmail': toEmail,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    _logFirestoreOp('WRITE_BATCH_COMMIT', _db.collection('groupStudyRequests').path);
    await batch.commit();

    // Backward compatibility for chat list queries that still use this format.
    final roomRef = _db.collection('course_study_rooms').doc(groupRef.id);
    _logFirestoreOp('WRITE_SET', roomRef.path);
    await roomRef.set({
      'courseId': courseId,
      'courseName': courseName,
      'groupId': groupRef.id,
      'createdBy': user.uid,
      'createdByName': creatorName,
      'memberIds': [user.uid],
      'memberNames': {user.uid: creatorName},
      'status': 'open',
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Best-effort email notification: in-app request already exists even if email fails.
    try {
      await ApiService().sendCourseRoomInviteEmails(
        recipientEmails: invitedEmails,
        courseName: courseName,
        inviterName: creatorName,
      );
    } catch (_) {}
    return invitedUserIds.length;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> incomingRequestsStream(
    String userId,
  ) {
    _logFirestoreOp('READ_STREAM', _db.collection('groupStudyRequests').path);
    if (kDebugMode) {
      debugPrint('[CourseRoom] incomingRequests currentUser.uid=$userId');
    }
    return _db
        .collection('groupStudyRequests')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          if (kDebugMode) {
            debugPrint(
              '[CourseRoom] incomingRequests fetchedCount=${snapshot.docs.length}',
            );
          }
          return snapshot;
        });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> myRoomsStream(
    String userId,
  ) {
    _logFirestoreOp('READ_STREAM', _db.collection('course_study_rooms').path);
    return _db
        .collection('course_study_rooms')
        .where('memberIds', arrayContains: userId)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> roomMessagesStream(
    String roomId,
  ) {
    final messagesPath = _db
        .collection('course_study_rooms')
        .doc(roomId)
        .collection('messages')
        .path;
    _logFirestoreOp('READ_STREAM', messagesPath);
    return _db
        .collection('course_study_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }

  static Future<void> rejectRequest(String requestId, String userId) async {
    final requestRef = _db.collection('groupStudyRequests').doc(requestId);
    _logFirestoreOp('WRITE_UPDATE', requestRef.path);
    await requestRef.update({
      'status': 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<AcceptRequestResult> acceptRequest({
    required String requestId,
    required String userId,
  }) async {
    var acceptedGroupId = '';
    var acceptedRoomId = '';
    if (kDebugMode) {
      debugPrint('[CourseRoom] accepted requestId=$requestId');
    }
    _logFirestoreOp('READ_WRITE_TRANSACTION', 'groupStudyRequests/$requestId');
    await _db.runTransaction((tx) async {
      final reqRef = _db.collection('groupStudyRequests').doc(requestId);
      _logFirestoreOp('READ_TX_GET', reqRef.path);
      final reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) throw Exception('Request not found.');

      final data = reqSnap.data() as Map<String, dynamic>;
      final courseId = (data['courseId'] as String?) ?? '';
      final courseName = (data['courseName'] as String?) ?? 'Course Room';
      final groupId = (data['groupId'] as String?) ?? '';
      final creatorId = (data['fromUserId'] as String?) ?? '';
      final creatorName = (data['fromUserName'] as String?) ?? 'Creator';
      if (courseId.isEmpty || creatorId.isEmpty || groupId.isEmpty) {
        throw Exception('Invalid request.');
      }
      acceptedGroupId = groupId;

      final roomRef = _db.collection('course_study_rooms').doc(groupId);
      acceptedRoomId = roomRef.id;
      _logFirestoreOp('READ_TX_GET', roomRef.path);
      final roomSnap = await tx.get(roomRef);
      final groupRef = _db.collection('groupStudies').doc(groupId);
      _logFirestoreOp('READ_TX_GET', groupRef.path);
      final groupSnap = await tx.get(groupRef);

      final me = FirebaseAuth.instance.currentUser;
      final myName = me?.displayName ?? me?.email ?? 'Student';

      if (!groupSnap.exists) {
        _logFirestoreOp('WRITE_TX_SET', groupRef.path);
        tx.set(groupRef, {
          'courseId': courseId,
          'courseName': courseName,
          'createdBy': creatorId,
          'createdByName': creatorName,
          'status': 'open',
          'memberIds': [creatorId, userId],
          'memberNames': {
            creatorId: creatorName,
            userId: myName,
          },
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        _logFirestoreOp('WRITE_TX_UPDATE', groupRef.path);
        tx.update(groupRef, {
          'memberIds': FieldValue.arrayUnion([userId]),
          'memberNames.$userId': myName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final memberRef = groupRef.collection('members').doc(userId);
      _logFirestoreOp('WRITE_TX_SET', memberRef.path);
      tx.set(memberRef, {
        'userId': userId,
        'name': myName,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      if (!roomSnap.exists) {
        _logFirestoreOp('WRITE_TX_SET', roomRef.path);
        tx.set(roomRef, {
          'roomId': groupId,
          'groupId': groupId,
          'courseId': courseId,
          'courseName': courseName,
          'memberIds': [creatorId, userId],
          'memberNames': {
            creatorId: creatorName,
            userId: myName,
          },
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        _logFirestoreOp('WRITE_TX_UPDATE', roomRef.path);
        tx.update(roomRef, {
          'memberIds': FieldValue.arrayUnion([userId]),
          'memberNames.$userId': myName,
          'active': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      _logFirestoreOp('WRITE_TX_UPDATE', reqRef.path);
      tx.update(reqRef, {
        'status': 'accepted',
        'roomId': roomRef.id,
        'respondedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    if (kDebugMode) {
      debugPrint('[CourseRoom] accepted groupId=$acceptedGroupId');
      debugPrint('[CourseRoom] accepted course_study_rooms roomId=$acceptedRoomId');
    }
    return AcceptRequestResult(
      requestId: requestId,
      groupId: acceptedGroupId,
      roomId: acceptedRoomId,
    );
  }

  static Future<void> sendRoomMessage({
    required String roomId,
    required String text,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Please log in first.');
    final message = text.trim();
    if (message.isEmpty) return;

    final roomRef = _db.collection('course_study_rooms').doc(roomId);
    final messagesRef = roomRef.collection('messages');
    _logFirestoreOp('WRITE_ADD', messagesRef.path);
    await messagesRef.add({
      'senderId': user.uid,
      'senderName': user.displayName ?? user.email ?? 'Student',
      'content': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _logFirestoreOp('WRITE_UPDATE', roomRef.path);
    await roomRef.update({
      'lastMessage': message,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
