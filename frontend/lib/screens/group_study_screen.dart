import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/classroom_provider.dart';
import '../services/course_room_service.dart';

class GroupStudyScreen extends StatefulWidget {
  final VoidCallback? openDrawer;

  const GroupStudyScreen({super.key, this.openDrawer});

  @override
  State<GroupStudyScreen> createState() => _GroupStudyScreenState();
}

class _GroupStudyScreenState extends State<GroupStudyScreen> {
  final TextEditingController _chatController = TextEditingController();
  String? _selectedCourseId;
  String? _selectedRoomId;
  bool _isSendingRequest = false;

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _sendCourseRequest() async {
    final classroom = context.read<ClassroomProvider>();
    if (_selectedCourseId == null) {
      _showMessage('Select a course first.');
      return;
    }
    final course = classroom.courses.firstWhere(
      (c) => c.id == _selectedCourseId,
      orElse: () => classroom.courses.first,
    );

    setState(() => _isSendingRequest = true);
    try {
      final invitedCount = await CourseRoomService.sendCourseRoomRequest(
        courseId: course.id,
        courseName: course.name,
      );
      if (!mounted) return;
      _showMessage('Request sent to $invitedCount classmates.');
    } catch (e) {
      if (mounted) {
        _showMessage(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSendingRequest = false);
    }
  }

  Future<void> _sendChatMessage() async {
    if (_selectedRoomId == null) return;
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    await CourseRoomService.sendRoomMessage(roomId: _selectedRoomId!, text: text);
    _chatController.clear();
  }

  Future<void> _acceptRequest(String requestId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final accepted = await CourseRoomService.acceptRequest(
      requestId: requestId,
      userId: uid,
    );
    if (!mounted) return;
    setState(() {
      _selectedRoomId = accepted.groupId;
    });
    if (kDebugMode) {
      debugPrint('[GroupStudy] accepted requestId=${accepted.requestId}');
      debugPrint('[GroupStudy] accepted groupId=${accepted.groupId}');
      debugPrint('[GroupStudy] accepted roomId=${accepted.roomId}');
      debugPrint('[GroupStudy] selected active room after accept=$_selectedRoomId');
    }
    _showMessage('Joined room.');
  }

  Future<void> _rejectRequest(String requestId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await CourseRoomService.rejectRequest(requestId, uid);
    if (mounted) _showMessage('Request rejected.');
  }

  @override
  Widget build(BuildContext context) {
    final classroom = context.watch<ClassroomProvider>();
    final user = FirebaseAuth.instance.currentUser;
    final courses = classroom.courses;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in first.')));
    }

    if (_selectedCourseId == null && courses.isNotEmpty) {
      _selectedCourseId = courses.first.id;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Navigator.canPop(context)
                ? Icons.arrow_back
                : (widget.openDrawer != null ? Icons.menu : Icons.arrow_back),
          ),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.maybePop(context);
            } else if (widget.openDrawer != null) {
              widget.openDrawer!();
            }
          },
        ),
        title: const Text('Course Study Rooms'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 1100;
          final requestPanel = Container(
            width: isNarrow ? double.infinity : 420,
            color: AppTheme.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Request Study Room',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a course and invite all enrolled classmates.',
                  style: TextStyle(color: AppTheme.mediumGray),
                ),
                const SizedBox(height: 16),
                if (courses.isEmpty)
                  const Text('No courses found. Sync Classroom first.')
                else
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedCourseId,
                    decoration: const InputDecoration(
                      labelText: 'Course',
                      border: OutlineInputBorder(),
                    ),
                    items: courses
                        .map(
                          (course) => DropdownMenuItem(
                            value: course.id,
                            child: Text(
                              course.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selectedCourseId = value),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSendingRequest ? null : _sendCourseRequest,
                    icon: _isSendingRequest
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: const Text('Send Course Room Request'),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Incoming Invitations',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: CourseRoomService.incomingRequestsStream(user.uid),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text('Could not load invitations right now.'),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data?.docs ??
                          const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('No pending invitations.'),
                        );
                      }
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final Map<String, dynamic> data = doc.data();
                          return Card(
                            child: ListTile(
                              title: Text(data['courseName']?.toString() ?? 'Course'),
                              subtitle: Text(
                                'Requested by ${data['fromUserName'] ?? data['creatorName'] ?? 'Student'}',
                              ),
                              trailing: Wrap(
                                spacing: 6,
                                children: [
                                  TextButton(
                                    onPressed: () => _rejectRequest(doc.id),
                                    child: const Text('Reject'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => _acceptRequest(doc.id),
                                    child: const Text('Accept'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );

          final roomsPanel = Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: CourseRoomService.myRoomsStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rooms = snapshot.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                if (kDebugMode) {
                  debugPrint('Rooms fetched: ${rooms.length}');
                }
                if (rooms.isEmpty) {
                  return Center(
                    child: Text(
                      'No active room yet.\nSend or accept a course invitation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.mediumGray),
                    ),
                  );
                }
                _selectedRoomId ??= rooms.first.id;
                final selectedIndex =
                    rooms.indexWhere((r) => r.id == _selectedRoomId);
                final selected = selectedIndex >= 0
                    ? rooms[selectedIndex]
                    : rooms.first;
                final Map<String, dynamic> roomData = selected.data();
                final memberIds =
                    (roomData['memberIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

                return Column(
                  children: [
                    Container(
                      color: AppTheme.white,
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedRoomId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Active room',
                                border: OutlineInputBorder(),
                              ),
                              items: rooms
                                  .map(
                                    (room) => DropdownMenuItem<String>(
                                      value: room.id,
                                      child: Text(
                                        room.data()['courseName']?.toString() ?? room.id,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _selectedRoomId = value),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('${memberIds.length} members'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: CourseRoomService.roomMessagesStream(selected.id),
                        builder: (context, msgSnapshot) {
                          final messages = msgSnapshot.data?.docs ??
                              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final Map<String, dynamic> data =
                                  messages[index].data();
                              final senderId = data['senderId']?.toString() ?? '';
                              final isMe = senderId == user.uid;
                              final senderName =
                                  data['senderName']?.toString() ?? 'Student';
                              final content = data['content']?.toString() ?? '';
                              final ts = data['createdAt'];
                              final when = ts is Timestamp
                                  ? DateFormat('h:mm a').format(ts.toDate())
                                  : '';
                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(10),
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? AppTheme.primaryBlue
                                        : AppTheme.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (!isMe)
                                        Text(
                                          senderName,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      Text(
                                        content,
                                        style: TextStyle(
                                          color: isMe ? AppTheme.white : AppTheme.darkText,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        when,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isMe
                                              ? AppTheme.white.withOpacity(0.85)
                                              : AppTheme.mediumGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Container(
                      color: AppTheme.white,
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatController,
                              decoration: const InputDecoration(
                                hintText: 'Ask a question in the room...',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _sendChatMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _sendChatMessage,
                            icon: const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );

          if (isNarrow) {
            return Column(
              children: [
                SizedBox(height: 420, child: requestPanel),
                const Divider(height: 1),
                roomsPanel,
              ],
            );
          }
          return Row(
            children: [
              requestPanel,
              roomsPanel,
            ],
          );
        },
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
