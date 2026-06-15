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

    if (invitedUserIds.isEmpty) {
      throw Exception('No enrolled classmates found for this course.');
    }

    final creatorName = user.displayName ?? user.email ?? 'Student';

    final pendingSnap = await _db
        .collection('groupStudyRequests')
        .where('courseId', isEqualTo: courseId)
        .where('fromUserId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .get();
    final pendingInviteUserIds = pendingSnap.docs
        .map((doc) => (doc.data()['toUserId'] as String?) ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    if (kDebugMode) {
      debugPrint(
        '[CourseRoom] Pending invites from ${user.uid} for courseId=$courseId: '
        '${pendingInviteUserIds.length}',
      );
    }

    final batch = _db.batch();
    var newInviteCount = 0;
    final newInviteEmails = <String>[];
    _logFirestoreOp('WRITE_BATCH_START', _db.collection('groupStudyRequests').path);
    for (final doc in invitedDocs) {
      final toUserId = doc.id;
      if (pendingInviteUserIds.contains(toUserId)) {
        if (kDebugMode) {
          debugPrint(
            '[CourseRoom] Skip invite: $toUserId already has pending request '
            'for courseId=$courseId from ${user.uid}',
          );
        }
        continue;
      }

      final Map<String, dynamic> data = doc.data();
      final toEmail = (data['email'] as String?) ?? '';
      final reqRef = _db.collection('groupStudyRequests').doc();
      _logFirestoreOp('WRITE_BATCH_SET', reqRef.path);
      batch.set(reqRef, {
        'courseId': courseId,
        'courseName': courseName,
        'fromUserId': user.uid,
        'fromUserName': creatorName,
        'toUserId': toUserId,
        'toEmail': toEmail,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      newInviteCount++;
      if (toEmail.trim().contains('@')) {
        newInviteEmails.add(toEmail.trim());
      }
    }

    if (newInviteCount == 0) {
      throw Exception(
        'No new invitations to send. Classmates already have pending invites.',
      );
    }

    _logFirestoreOp('WRITE_BATCH_COMMIT', _db.collection('groupStudyRequests').path);
    await batch.commit();

    if (kDebugMode) {
      debugPrint(
        '[CourseRoom] Sent $newInviteCount invite(s) for courseId=$courseId '
        '(no room created until accept)',
      );
    }

    // Best-effort email notification: in-app request already exists even if email fails.
    try {
      await ApiService().sendCourseRoomInviteEmails(
        recipientEmails: newInviteEmails,
        courseName: courseName,
        inviterName: creatorName,
      );
    } catch (_) {}
    return newInviteCount;
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
        .snapshots()
        .map((snapshot) {
          if (kDebugMode) {
            final email =
                FirebaseAuth.instance.currentUser?.email ?? '(no email)';
            debugPrint('Current UID: $userId');
            debugPrint('Current email: $email');
            debugPrint(
              '[CourseRoom] myRoomsStream fetchedCount=${snapshot.docs.length}',
            );
            for (final room in snapshot.docs) {
              debugPrint('Room ID: ${room.id}');
              debugPrint('Members: ${room.data()['memberIds']}');
            }
          }
          return snapshot;
        });
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
      debugPrint('[CourseRoom] accept requestId=$requestId userId=$userId');
    }

    final reqRef = _db.collection('groupStudyRequests').doc(requestId);
    _logFirestoreOp('READ_GET', reqRef.path);
    final reqPreview = await reqRef.get();
    if (!reqPreview.exists) throw Exception('Request not found.');

    final previewData = reqPreview.data() as Map<String, dynamic>;
    final previewCourseId = (previewData['courseId'] as String?) ?? '';
    if (previewCourseId.isEmpty) throw Exception('Invalid request.');

    final roomsPath = _db.collection('course_study_rooms').path;
    _logFirestoreOp('READ_QUERY', roomsPath);
    final existingRoomSnap = await _db
        .collection('course_study_rooms')
        .where('courseId', isEqualTo: previewCourseId)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();

    final newGroupRef = _db.collection('groupStudies').doc();
    final newRoomRef =
        _db.collection('course_study_rooms').doc(newGroupRef.id);

    _logFirestoreOp('READ_WRITE_TRANSACTION', 'groupStudyRequests/$requestId');
    await _db.runTransaction((tx) async {
      _logFirestoreOp('READ_TX_GET', reqRef.path);
      final reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) throw Exception('Request not found.');

      final data = reqSnap.data() as Map<String, dynamic>;
      final status = (data['status'] as String?) ?? '';
      if (status != 'pending') {
        throw Exception('Request is no longer pending.');
      }

      final courseId = (data['courseId'] as String?) ?? '';
      final courseName = (data['courseName'] as String?) ?? 'Course Room';
      final creatorId = (data['fromUserId'] as String?) ?? '';
      final creatorName = (data['fromUserName'] as String?) ?? 'Creator';
      if (courseId.isEmpty || creatorId.isEmpty) {
        throw Exception('Invalid request.');
      }

      final me = FirebaseAuth.instance.currentUser;
      final myName = me?.displayName ?? me?.email ?? 'Student';

      DocumentReference<Map<String, dynamic>> roomRef;
      DocumentReference<Map<String, dynamic>> groupRef;

      if (existingRoomSnap.docs.isNotEmpty) {
        final existingDoc = existingRoomSnap.docs.first;
        final existingData = existingDoc.data();
        acceptedRoomId = existingDoc.id;
        acceptedGroupId =
            (existingData['groupId'] as String?) ?? existingDoc.id;
        roomRef = existingDoc.reference;
        groupRef = _db.collection('groupStudies').doc(acceptedGroupId);

        if (kDebugMode) {
          debugPrint(
            '[CourseRoom] Existing room found on accept: roomId=$acceptedRoomId '
            'groupId=$acceptedGroupId courseId=$courseId',
          );
          debugPrint('[CourseRoom] Existing room reused on accept');
        }

        _logFirestoreOp('READ_TX_GET', roomRef.path);
        final roomSnap = await tx.get(roomRef);
        if (!roomSnap.exists) {
          throw Exception('Study room no longer exists. Please try again.');
        }

        _logFirestoreOp('READ_TX_GET', groupRef.path);
        final groupSnap = await tx.get(groupRef);

        _logFirestoreOp('WRITE_TX_UPDATE', roomRef.path);
        tx.update(roomRef, {
          'memberIds': FieldValue.arrayUnion([creatorId, userId]),
          'memberNames.$creatorId': creatorName,
          'memberNames.$userId': myName,
          'active': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (groupSnap.exists) {
          _logFirestoreOp('WRITE_TX_UPDATE', groupRef.path);
          tx.update(groupRef, {
            'memberIds': FieldValue.arrayUnion([creatorId, userId]),
            'memberNames.$creatorId': creatorName,
            'memberNames.$userId': myName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        groupRef = newGroupRef;
        acceptedGroupId = groupRef.id;
        roomRef = newRoomRef;
        acceptedRoomId = roomRef.id;

        _logFirestoreOp('READ_TX_GET', roomRef.path);
        final roomSnap = await tx.get(roomRef);
        if (roomSnap.exists) {
          final existingData = roomSnap.data() as Map<String, dynamic>;
          acceptedGroupId =
              (existingData['groupId'] as String?) ?? roomRef.id;
          groupRef = _db.collection('groupStudies').doc(acceptedGroupId);

          if (kDebugMode) {
            debugPrint(
              '[CourseRoom] Room created concurrently; reusing roomId=$acceptedRoomId',
            );
          }

          _logFirestoreOp('READ_TX_GET', groupRef.path);
          final groupSnap = await tx.get(groupRef);

          _logFirestoreOp('WRITE_TX_UPDATE', roomRef.path);
          tx.update(roomRef, {
            'memberIds': FieldValue.arrayUnion([creatorId, userId]),
            'memberNames.$creatorId': creatorName,
            'memberNames.$userId': myName,
            'active': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          if (groupSnap.exists) {
            _logFirestoreOp('WRITE_TX_UPDATE', groupRef.path);
            tx.update(groupRef, {
              'memberIds': FieldValue.arrayUnion([creatorId, userId]),
              'memberNames.$creatorId': creatorName,
              'memberNames.$userId': myName,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } else {
          if (kDebugMode) {
            debugPrint(
              '[CourseRoom] No active room for courseId=$courseId; '
              'creating on accept',
            );
          }

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

          _logFirestoreOp('WRITE_TX_SET', roomRef.path);
          tx.set(roomRef, {
            'roomId': acceptedGroupId,
            'groupId': acceptedGroupId,
            'courseId': courseId,
            'courseName': courseName,
            'createdBy': creatorId,
            'createdByName': creatorName,
            'memberIds': [creatorId, userId],
            'memberNames': {
              creatorId: creatorName,
              userId: myName,
            },
            'status': 'open',
            'active': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          if (kDebugMode) {
            debugPrint(
              '[CourseRoom] New room created on accept: roomId=$acceptedRoomId '
              'groupId=$acceptedGroupId',
            );
          }
        }
      }

      final memberRef = groupRef.collection('members').doc(userId);
      _logFirestoreOp('WRITE_TX_SET', memberRef.path);
      tx.set(memberRef, {
        'userId': userId,
        'name': myName,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      _logFirestoreOp('WRITE_TX_UPDATE', reqRef.path);
      tx.update(reqRef, {
        'status': 'accepted',
        'groupId': acceptedGroupId,
        'roomId': acceptedRoomId,
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

  static Future<void> leaveRoom({
    required String roomId,
    required String userId,
  }) async {
    final roomRef = _db.collection('course_study_rooms').doc(roomId);
    _logFirestoreOp('READ_GET', roomRef.path);
    final roomSnap = await roomRef.get();
    if (!roomSnap.exists) throw Exception('Room not found.');

    final data = roomSnap.data() ?? {};
    final memberIds = _memberIdsFromRoomData(data);
    if (!memberIds.contains(userId)) {
      throw Exception('You are not a member of this room.');
    }

    final remainingMemberIds =
        memberIds.where((id) => id != userId).toList();
    final memberNames = Map<String, dynamic>.from(
      data['memberNames'] is Map ? data['memberNames'] as Map : {},
    );
    memberNames.remove(userId);

    final groupId = (data['groupId'] as String?) ?? roomId;
    final groupRef = _db.collection('groupStudies').doc(groupId);

    if (remainingMemberIds.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[CourseRoom] leaveRoom: no members remain; deleting roomId=$roomId',
        );
      }
      await _deleteMessagesSubcollection(roomRef);
      _logFirestoreOp('WRITE_DELETE', roomRef.path);
      await roomRef.delete();

      _logFirestoreOp('READ_GET', groupRef.path);
      final groupSnap = await groupRef.get();
      if (groupSnap.exists) {
        _logFirestoreOp('WRITE_DELETE', groupRef.path);
        await groupRef.delete();
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '[CourseRoom] leaveRoom: userId=$userId left roomId=$roomId; '
        'remaining=${remainingMemberIds.length}',
      );
    }

    _logFirestoreOp('WRITE_UPDATE', roomRef.path);
    await roomRef.update({
      'memberIds': remainingMemberIds,
      'memberNames': memberNames,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _logFirestoreOp('READ_GET', groupRef.path);
    final groupSnap = await groupRef.get();
    if (groupSnap.exists) {
      final groupData = groupSnap.data() ?? {};
      final groupMemberIds = _memberIdsFromRoomData(groupData);
      final remainingGroupMemberIds =
          groupMemberIds.where((id) => id != userId).toList();
      final groupMemberNames = Map<String, dynamic>.from(
        groupData['memberNames'] is Map ? groupData['memberNames'] as Map : {},
      );
      groupMemberNames.remove(userId);

      _logFirestoreOp('WRITE_UPDATE', groupRef.path);
      await groupRef.update({
        'memberIds': remainingGroupMemberIds,
        'memberNames': groupMemberNames,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final memberDocRef = groupRef.collection('members').doc(userId);
      _logFirestoreOp('WRITE_DELETE', memberDocRef.path);
      await memberDocRef.delete();
    }
  }

  static Set<String> _memberIdsFromRoomData(Map<String, dynamic> data) {
    final rawMembers = data['memberIds'];
    if (rawMembers is! List) return {};
    return rawMembers.map((e) => e.toString()).toSet();
  }

  static Future<void> _deleteMessagesSubcollection(
    DocumentReference<Map<String, dynamic>> roomRef,
  ) async {
    const pageSize = 200;
    while (true) {
      final messagesPath = roomRef.collection('messages').path;
      _logFirestoreOp('READ_QUERY', messagesPath);
      final snap =
          await roomRef.collection('messages').limit(pageSize).get();
      if (snap.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      _logFirestoreOp('WRITE_BATCH_COMMIT', messagesPath);
      await batch.commit();

      if (snap.docs.length < pageSize) break;
    }
  }
}
