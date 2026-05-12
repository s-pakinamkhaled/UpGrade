import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/classroom_provider.dart';
import '../services/course_room_service.dart';
import '../widgets/upgrade_visual_system.dart';

/// Sort chat docs by [createdAt] in memory (avoids Firestore Web issues with
/// [orderBy] when some messages lack a resolved timestamp).
int _compareRoomMessagesByTime(
  QueryDocumentSnapshot<Map<String, dynamic>> a,
  QueryDocumentSnapshot<Map<String, dynamic>> b,
) {
  final ta = a.data()['createdAt'];
  final tb = b.data()['createdAt'];
  if (ta is Timestamp && tb is Timestamp) return ta.compareTo(tb);
  if (ta is Timestamp) return -1;
  if (tb is Timestamp) return 1;
  return a.id.compareTo(b.id);
}

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
  /// Hides invitation rows immediately on Accept/Reject; cleared if the call fails.
  final Set<String> _dismissingRequestIds = {};

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
    setState(() => _dismissingRequestIds.add(requestId));
    try {
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _dismissingRequestIds.remove(requestId));
      _showMessage(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _dismissingRequestIds.add(requestId));
    try {
      await CourseRoomService.rejectRequest(requestId, uid);
      if (mounted) _showMessage('Request rejected.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _dismissingRequestIds.remove(requestId));
      _showMessage(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Widget _stripeSectionTitle(String title, UpGradeRem rem, Color onSurface) {
    return Row(
      children: [
        Container(
          width: 4,
          height: rem.sectionTitle * 1.2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: AppTheme.primaryGradient,
            boxShadow: AppTheme.softShadow,
          ),
        ),
        SizedBox(width: rem.space(0.65)),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: rem.sectionTitle,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.35,
              color: onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _invitationCard({
    required UpGradeRem rem,
    required bool isDark,
    required String requestId,
    required String courseName,
    required String requesterName,
    required Color onSurface,
    required Color muted,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: rem.space(0.65)),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E293B),
                  AppTheme.primaryBlue.withOpacity(0.08),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFF5F3FF),
                ],
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(isDark ? 0.4 : 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(isDark ? 0.18 : 0.1),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: AppTheme.secondaryPurple.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.all(rem.space(0.9)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(
                  courseName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: rem.listTitle,
                    letterSpacing: -0.2,
                    color: onSurface,
                  ),
                ),
                SizedBox(height: rem.space(0.35)),
                Text(
                  'Requested by $requesterName',
                  style: TextStyle(
                    fontSize: rem.listSubtitle,
                    color: muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: rem.space(0.75)),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _rejectRequest(requestId),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        padding: EdgeInsets.symmetric(horizontal: rem.space(0.5)),
                      ),
                      child: Text(
                        'Reject',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: rem.listSubtitle,
                        ),
                      ),
                    ),
                    const Spacer(),
                    UpGradeGradientFilledButton(
                      onPressed: () => _acceptRequest(requestId),
                      icon: Icon(Icons.check_rounded, size: rem.iconSmall * 0.95),
                      label: Text(
                        'Accept',
                        style: TextStyle(
                          fontSize: rem.buttonLabel,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: rem.space(1.05),
                        vertical: rem.space(0.55),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final layoutW = MediaQuery.sizeOf(context).width;
    final rem = UpGradeRem(layoutW);

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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Navigator.canPop(context)
                ? Icons.arrow_back
                : (widget.openDrawer != null ? Icons.menu : Icons.arrow_back),
            color: onSurface,
          ),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.maybePop(context);
            } else if (widget.openDrawer != null) {
              widget.openDrawer!();
            }
          },
        ),
        title: UpGradeGradientTitle('Study Group', rem: rem, isDark: isDark),
      ),
      body: DecoratedBox(
        decoration: UpGradePageDecor.pageBackground(isDark),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 1100;
            final panelRem = UpGradeRem(
              constraints.maxWidth.isFinite && constraints.maxWidth > 0
                  ? constraints.maxWidth
                  : layoutW,
            );

            final requestPanel = SizedBox(
              width: isNarrow ? double.infinity : 420,
              child: Padding(
                padding: EdgeInsets.all(panelRem.space(1.0)),
                child: UpGradeListSectionPanel(
                  rem: panelRem,
                  isDark: isDark,
                  tintTop: AppTheme.primaryBlue.withOpacity(0.14),
                  borderAccent: AppTheme.primaryBlue,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _stripeSectionTitle('Invite classmates', panelRem, onSurface),
                      SizedBox(height: panelRem.space(0.45)),
                      UpGradeMutedSubtitle(
                        'Select a course and send a study group invite to everyone enrolled.',
                        rem: panelRem,
                        isDark: isDark,
                      ),
                      SizedBox(height: panelRem.space(1.0)),
                      if (courses.isEmpty)
                        Text(
                          'No courses found. Sync Classroom first.',
                          style: TextStyle(
                            color: muted,
                            fontSize: panelRem.cardBody,
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedCourseId,
                          decoration: UpGradeInputDecor.themed(
                            context,
                            panelRem,
                            '',
                          ).copyWith(
                            labelText: 'Course',
                            hintText: null,
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
                          onChanged: (value) =>
                              setState(() => _selectedCourseId = value),
                        ),
                      SizedBox(height: panelRem.space(0.85)),
                      SizedBox(
                        width: double.infinity,
                        child: UpGradeGradientFilledButton(
                          onPressed: _isSendingRequest ? null : _sendCourseRequest,
                          icon: const Icon(Icons.send_rounded),
                          label: _isSendingRequest
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: panelRem.iconSmall * 0.9,
                                      height: panelRem.iconSmall * 0.9,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: panelRem.space(0.45)),
                                    Text(
                                      'Sending…',
                                      style: TextStyle(
                                        fontSize: panelRem.buttonLabel,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  'Send study group invite',
                                  style: TextStyle(
                                    fontSize: panelRem.buttonLabel,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                          padding: EdgeInsets.symmetric(
                            horizontal: panelRem.space(1.2),
                            vertical: panelRem.space(0.85),
                          ),
                        ),
                      ),
                      SizedBox(height: panelRem.space(1.25)),
                      _stripeSectionTitle('Incoming invitations', panelRem, onSurface),
                      SizedBox(height: panelRem.space(0.65)),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: CourseRoomService.incomingRequestsStream(user.uid),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Could not load invitations right now.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: muted),
                                ),
                              );
                            }
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryBlue,
                                ),
                              );
                            }
                            final allDocs = snapshot.data?.docs ??
                                const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                            final docs = allDocs
                                .where((d) => !_dismissingRequestIds.contains(d.id))
                                .toList();
                            if (docs.isEmpty) {
                              return Center(
                                child: Text(
                                  'No pending invitations.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: panelRem.cardBody,
                                  ),
                                ),
                              );
                            }
                            return ListView.builder(
                              padding: EdgeInsets.only(top: panelRem.space(0.35)),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final Map<String, dynamic> data = doc.data();
                                final courseName =
                                    data['courseName']?.toString() ?? 'Course';
                                final requesterName =
                                    data['fromUserName']?.toString() ??
                                        data['creatorName']?.toString() ??
                                        'Student';
                                return _invitationCard(
                                  rem: panelRem,
                                  isDark: isDark,
                                  requestId: doc.id,
                                  courseName: courseName,
                                  requesterName: requesterName,
                                  onSurface: onSurface,
                                  muted: muted,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );

            final roomsPanel = Expanded(
              child: Padding(
                padding: EdgeInsets.all(panelRem.space(0.85)),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: CourseRoomService.myRoomsStream(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryBlue,
                        ),
                      );
                    }
                    final rooms = snapshot.data?.docs ??
                        const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    if (kDebugMode) {
                      debugPrint('Rooms fetched: ${rooms.length}');
                    }
                    if (rooms.isEmpty) {
                      return Center(
                        child: Container(
                          padding: EdgeInsets.all(panelRem.space(1.5)),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            color: isDark
                                ? const Color(0xFF111827)
                                : Colors.white,
                            border: Border.all(
                              color: AppTheme.primaryBlue.withOpacity(0.18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryBlue.withOpacity(0.08),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Text(
                            'No active room yet.\nSend or accept a study group invite.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: muted,
                              fontSize: panelRem.cardBody,
                              height: 1.45,
                            ),
                          ),
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
                    final rawMembers = roomData['memberIds'];
                    final memberIds = rawMembers is List
                        ? rawMembers.map((e) => e.toString()).toList()
                        : <String>[];

                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : AppTheme.primaryBlue.withOpacity(0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withOpacity(
                              isDark ? 0.14 : 0.09,
                            ),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: AppTheme.secondaryPurple.withOpacity(0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(panelRem.space(0.85)),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF111827)
                                  : Colors.white,
                              border: Border(
                                bottom: BorderSide(
                                  color: AppTheme.primaryBlue.withOpacity(0.12),
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedRoomId,
                                    isExpanded: true,
                                    decoration: UpGradeInputDecor.themed(
                                      context,
                                      panelRem,
                                      '',
                                    ).copyWith(
                                      labelText: 'Active room',
                                      hintText: null,
                                    ),
                                    items: rooms
                                        .map(
                                          (room) => DropdownMenuItem<String>(
                                            value: room.id,
                                            child: Text(
                                              room
                                                      .data()['courseName']
                                                      ?.toString() ??
                                                  room.id,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) => setState(
                                      () => _selectedRoomId = value,
                                    ),
                                  ),
                                ),
                                SizedBox(width: panelRem.space(0.65)),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: panelRem.space(0.55),
                                    vertical: panelRem.space(0.35),
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryPurple.withOpacity(
                                      isDark ? 0.22 : 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.secondaryPurple.withOpacity(
                                        0.28,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '${memberIds.length} members',
                                    style: TextStyle(
                                      fontSize: panelRem.listSubtitle,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? const Color(0xFFE9D5FF)
                                          : AppTheme.secondaryPurple,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: isDark
                                    ? const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF0F172A),
                                          Color(0xFF1A1033),
                                        ],
                                      )
                                    : const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFFF8FAFF),
                                          Color(0xFFF3E8FF),
                                        ],
                                      ),
                              ),
                              child: StreamBuilder<
                                  QuerySnapshot<Map<String, dynamic>>>(
                                stream: CourseRoomService.roomMessagesStream(
                                  selected.id,
                                ),
                                builder: (context, msgSnapshot) {
                                  final messages =
                                      List<QueryDocumentSnapshot<
                                          Map<String, dynamic>>>.from(
                                    msgSnapshot.data?.docs ??
                                        const <
                                            QueryDocumentSnapshot<
                                                Map<String, dynamic>>>[],
                                  )..sort(_compareRoomMessagesByTime);
                                  return ListView.builder(
                                    padding: EdgeInsets.all(panelRem.space(1.0)),
                                    itemCount: messages.length,
                                    itemBuilder: (context, index) {
                                      final Map<String, dynamic> data =
                                          messages[index].data();
                                      final senderId =
                                          data['senderId']?.toString() ?? '';
                                      final isMe = senderId == user.uid;
                                      final senderName =
                                          data['senderName']?.toString() ??
                                              'Student';
                                      final content =
                                          data['content']?.toString() ?? '';
                                      final ts = data['createdAt'];
                                      final when = ts is Timestamp
                                          ? DateFormat('h:mm a')
                                              .format(ts.toDate())
                                          : '';
                                      return Align(
                                        alignment: isMe
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: Container(
                                          margin: EdgeInsets.only(
                                            bottom: panelRem.space(0.65),
                                          ),
                                          padding: EdgeInsets.all(
                                            panelRem.space(0.75),
                                          ),
                                          constraints: BoxConstraints(
                                            maxWidth:
                                                MediaQuery.sizeOf(context).width *
                                                    0.52,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: isMe
                                                ? AppTheme.primaryGradient
                                                : null,
                                            color: isMe
                                                ? null
                                                : (isDark
                                                    ? const Color(0xFF1E293B)
                                                    : Colors.white),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: isMe
                                                ? null
                                                : Border.all(
                                                    color: AppTheme.primaryBlue
                                                        .withOpacity(0.15),
                                                  ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: (isMe
                                                        ? AppTheme.primaryBlue
                                                        : Colors.black)
                                                    .withOpacity(
                                                  isMe ? 0.22 : 0.06,
                                                ),
                                                blurRadius: isMe ? 12 : 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (!isMe)
                                                Text(
                                                  senderName,
                                                  style: TextStyle(
                                                    fontSize:
                                                        panelRem.listSubtitle *
                                                            0.88,
                                                    fontWeight: FontWeight.w800,
                                                    color: isDark
                                                        ? const Color(0xFF94A3B8)
                                                        : const Color(0xFF475569),
                                                  ),
                                                ),
                                              if (!isMe)
                                                SizedBox(
                                                  height: panelRem.space(0.25),
                                                ),
                                              Text(
                                                content,
                                                style: TextStyle(
                                                  color: isMe
                                                      ? Colors.white
                                                      : onSurface,
                                                  fontSize: panelRem.cardBody,
                                                  height: 1.35,
                                                ),
                                              ),
                                              SizedBox(
                                                height: panelRem.space(0.25),
                                              ),
                                              Text(
                                                when,
                                                style: TextStyle(
                                                  fontSize:
                                                      panelRem.listSubtitle *
                                                          0.85,
                                                  color: isMe
                                                      ? Colors.white
                                                          .withOpacity(0.88)
                                                      : muted,
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
                          ),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(panelRem.space(0.85)),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF111827)
                                  : Colors.white,
                              border: Border(
                                top: BorderSide(
                                  color: AppTheme.primaryBlue.withOpacity(0.12),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _chatController,
                                    style: TextStyle(
                                      fontSize: panelRem.inputText,
                                      color: onSurface,
                                    ),
                                    decoration:
                                        UpGradeInputDecor.themed(
                                      context,
                                      panelRem,
                                      'Ask a question in the room...',
                                    ),
                                    onSubmitted: (_) => _sendChatMessage(),
                                  ),
                                ),
                                SizedBox(width: panelRem.space(0.55)),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: AppTheme.primaryGradient,
                                    boxShadow: AppTheme.softShadow,
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _sendChatMessage,
                                      customBorder: const CircleBorder(),
                                      child: Padding(
                                        padding: EdgeInsets.all(
                                          panelRem.space(0.55),
                                        ),
                                        child: Icon(
                                          Icons.send_rounded,
                                          color: Colors.white,
                                          size: panelRem.iconSmall,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );

            if (isNarrow) {
              return Column(
                children: [
                  SizedBox(height: 440, child: requestPanel),
                  Divider(
                    height: 1,
                    color: AppTheme.primaryBlue.withOpacity(0.12),
                  ),
                  roomsPanel,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                requestPanel,
                roomsPanel,
              ],
            );
          },
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
