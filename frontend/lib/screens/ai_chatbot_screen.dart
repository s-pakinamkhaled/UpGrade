// ═══════════════════════════════════════════════════════════════════
// SCREEN: AI Chat  —  Real-time Study Assistant
// ═══════════════════════════════════════════════════════════════════
//
// DESCRIPTION
// -----------
// Full-screen conversational chat UI powered by Llama 3.3 (70B) via
// Groq. The assistant has access to the student's real Google Classroom
// tasks and provides personalised study advice, scheduling help,
// prioritisation guidance, and motivation.
//
// WORKFLOW
// --------
// 1. Screen opens  → _addWelcomeMessage()
//      Reads tasks from ClassroomProvider (Google Classroom sync).
//      Reads student name from FirebaseAuth.
//      Displays a greeting with task count & urgent count.
//
// 2. Student sends a message  → _sendMessage(text)
//      a) Adds the user message bubble to the list.
//      b) Shows a typing indicator animation.
//      c) Builds conversation_history from previous messages
//         (List<Map<String,String>> with role/content pairs).
//      d) Builds student_context with full task details:
//             name, tasks[]{title, courseName, priority, status,
//             deadline, estimatedMinutes, assignedGrade, maxPoints}
//      e) Calls ApiService.sendChatMessage() → POST /api/chat/message
//         (30-second timeout).
//
// 3. Backend calls AIChatService (ai/chat_service.py)
//      - Injects student context as a system message (up to 20 tasks).
//      - Appends last 10 conversation turns.
//      - Calls Groq API  (llama-3.3-70b-versatile, temp=0.7,
//        max_tokens=500).
//      - Returns {success, message, model, suggestions, error}.
//
// 4. Response received
//      - AI reply displayed in a chat bubble.
//      - suggestion chips rendered beneath the bubble for quick replies.
//      - If the API call fails or returns success=false,
//        _generateAIResponse() provides a local keyword-matched
//        fallback using the student's real task data.
//
// UI COMPONENTS
// -------------
// • AppBar          — title + help button
// • Quick Stats Bar — live task count + urgent count from ClassroomProvider
// • ListView        — chat bubbles (user right-aligned, AI left-aligned)
//                     + typing indicator (3-dot animation)
// • Suggestion Bar  — scrollable chips from last AI message
// • Input Row       — TextField + send button
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../models/task.dart';
import '../widgets/task_card.dart';
import '../services/api_service.dart';
import '../providers/classroom_provider.dart';

class AIChatbotScreen extends StatefulWidget {
  final VoidCallback? openDrawer;

  const AIChatbotScreen({super.key, this.openDrawer});

  @override
  State<AIChatbotScreen> createState() => _AIChatbotScreenState();
}

class _AIChatbotScreenState extends State<AIChatbotScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  late AnimationController _typingAnimationController;

  /// All synced Classroom rows plus manual tasks. Used for analytics/context.
  List<Task> get _studentTasks {
    try {
      return context.read<ClassroomProvider>().allSyncedItems;
    } catch (_) {
      return [];
    }
  }

  /// Only unfinished deliverables that can be scheduled by AI.
  List<Task> get _studentActionableTasks {
    try {
      return context.read<ClassroomProvider>().upcomingActionableTasks;
    } catch (_) {
      return [];
    }
  }

  /// Student display name from Firebase Auth.
  String get _studentName {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName ?? user?.email?.split('@').first ?? 'Student';
  }

  Map<String, dynamic> _taskContextJson(Task task) {
    return {
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'courseId': task.courseId,
      'courseName': task.courseName,
      'priority': task.priority.name,
      'status': task.status.name,
      'deadline': task.hasRealDeadline ? task.deadline.toIso8601String() : null,
      'estimatedMinutes': task.estimatedMinutes,
      'assignedGrade': task.assignedGrade,
      'maxPoints': task.maxPoints,
      'source': task.source,
      'itemType': task.itemType,
      'isActionableForAI': task.isActionableForAI,
      'isGradeRelated': task.isGradeRelated,
      'isDashboardOnly': task.isDashboardOnly,
      'classificationConfidence': task.classificationConfidence,
      'classificationReason': task.classificationReason,
      'classroomWorkType': task.classroomWorkType,
      'classroomSubmissionState': task.classroomSubmissionState,
      'classroomLate': task.classroomLate,
      'hasRealDeadline': task.hasRealDeadline,
      'deadlineSource': task.deadlineSource,
    };
  }

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    final allItems = _studentTasks;
    final tasks = _studentActionableTasks;
    final taskCount = tasks.length;
    final syncedCount = allItems.length;
    final urgentCount = tasks
        .where((t) =>
            t.priority == TaskPriority.urgent ||
            t.priority == TaskPriority.high)
        .length;

    final greeting = syncedCount > 0
        ? 'Hi $_studentName! I\'m your AI study assistant powered by Llama 3.3. '
            'You have **$taskCount actionable tasks** from **$syncedCount synced items**'
            '${urgentCount > 0 ? ' ($urgentCount urgent)' : ''}. '
            'Ask me anything about your studies!'
        : 'Hi $_studentName! I\'m your AI study assistant powered by Llama 3.3. '
            'Sync your Google Classroom data so I can give you personalised advice!';

    _messages.add(ChatMessage(
      text: greeting,
      isAI: true,
      timestamp: DateTime.now(),
      suggestions: [
        'What should I study now?',
        'Help me prioritize my tasks',
        'Show my schedule',
      ],
    ));
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isAI: false,
        timestamp: DateTime.now(),
      ));
    });

    _messageController.clear();
    _scrollToBottom();

    // Show typing indicator
    setState(() {
      _isTyping = true;
    });

    // Get AI response from backend (Llama 3.3)
    try {
      // Prepare conversation history (only user/assistant, skip welcome)
      final history = _messages
          .where((m) => m.text.isNotEmpty)
          .map((msg) => <String, String>{
                'role': msg.isAI ? 'assistant' : 'user',
                'content': msg.text,
              })
          .toList();
      // Remove last item (we already added the user message above)
      if (history.isNotEmpty) history.removeLast();

      // Build rich student context — send only actionable tasks to the AI,
      // but include personalization signals derived from ALL data.
      final provider = context.read<ClassroomProvider>();
      final actionableTasks = provider.upcomingActionableTasks;
      final signals = provider.personalizationSignals;
      final allSyncedItems = provider.allSyncedItems;

      final studentContext = <String, dynamic>{
        'name': _studentName,
        'tasks': actionableTasks.map(_taskContextJson).toList(),
        'actionableTasks': actionableTasks.map(_taskContextJson).toList(),
        'allSyncedItems': allSyncedItems.map(_taskContextJson).toList(),
        'analyticsContext': {
          'gradeItems': provider.gradeItems.map(_taskContextJson).toList(),
          'completedItems':
              provider.completedItems.map(_taskContextJson).toList(),
          'dashboardOnlyItems': allSyncedItems
              .where((task) => task.isDashboardOnly)
              .map(_taskContextJson)
              .toList(),
        },
        'personalizationSignals': signals,
      };

      // Call API
      final apiService = ApiService();
      final response = await apiService.sendChatMessage(
        message: text,
        conversationHistory: history,
        studentContext: studentContext,
      );

      if (mounted) {
        setState(() {
          _isTyping = false;

          if (response != null && response['success'] == true) {
            // Add AI response
            _messages.add(ChatMessage(
              text: response['message'] ??
                  'Sorry, I couldn\'t generate a response.',
              isAI: true,
              timestamp: DateTime.now(),
              suggestions: List<String>.from(response['suggestions'] ?? []),
            ));
          } else {
            // Fallback to local response if API fails
            _messages.add(_generateAIResponse(text));
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error calling AI API: $e');
      // Fallback to local mock response
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(_generateAIResponse(text));
        });
        _scrollToBottom();
      }
    }
  }

  ChatMessage _generateAIResponse(String userInput) {
    final lowerInput = userInput.toLowerCase();

    final tasks = _studentActionableTasks;
    final gradeItems =
        _studentTasks.where((task) => task.isGradeRelated).toList();
    // Natural language processing simulation
    if (lowerInput.contains('grade') ||
        lowerInput.contains('score') ||
        lowerInput.contains('mark') ||
        lowerInput.contains('result')) {
      if (gradeItems.isEmpty) {
        return ChatMessage(
          text:
              'I do not see any synced grade items yet. Your schedulable task list is kept separate from grade and progress rows.',
          isAI: true,
          timestamp: DateTime.now(),
          suggestions: ['Show my schedule', 'What should I study now?'],
        );
      }
      final shown = gradeItems.take(6).map((task) {
        final grade = task.assignedGrade != null
            ? ' - ${task.assignedGrade!.toStringAsFixed(0)}'
                '${task.maxPoints != null ? ' / ${task.maxPoints}' : ''}'
            : '';
        return '- ${task.title} (${task.courseName})$grade';
      }).join('\n');
      return ChatMessage(
        text:
            'Here are grade/progress items I found. I will use these for context only, not as tasks to schedule:\n\n$shown',
        isAI: true,
        timestamp: DateTime.now(),
        suggestions: ['What should I study now?', 'Help me prioritize'],
      );
    } else if (lowerInput.contains('study now') ||
        lowerInput.contains('what should') ||
        lowerInput.contains('next')) {
      if (tasks.isEmpty) {
        return ChatMessage(
          text:
              'You don\'t have any tasks right now. Sync your Google Classroom to get started!',
          isAI: true,
          timestamp: DateTime.now(),
          suggestions: ['Show my schedule', 'Help'],
        );
      }
      final nextTask = tasks.firstWhere(
        (task) =>
            task.scheduledTime != null &&
            task.scheduledTime!.isAfter(DateTime.now()),
        orElse: () => tasks.first,
      );
      final timeInfo = nextTask.scheduledTime != null
          ? 'It\'s scheduled for ${DateFormat('h:mm a').format(nextTask.scheduledTime!)} and will take about ${nextTask.estimatedMinutes} minutes. '
          : 'It will take about ${nextTask.estimatedMinutes} minutes. ';
      return ChatMessage(
        text:
            'Based on your schedule, I recommend starting with **${nextTask.title}**.\n\n${timeInfo}This is a ${nextTask.priority.label.toLowerCase()} priority task.\n\nWould you like me to start a focus session for this?',
        isAI: true,
        timestamp: DateTime.now(),
        relatedTask: nextTask,
        suggestions: [
          'Start focus session',
          'Reschedule this task',
          'Show all tasks',
        ],
      );
    } else if (lowerInput.contains('reschedule') ||
        lowerInput.contains('move') ||
        lowerInput.contains('change')) {
      final task = _findTaskInInput(userInput);

      if (task != null) {
        final currentTime = task.scheduledTime != null
            ? 'Current time: ${DateFormat('h:mm a').format(task.scheduledTime!)}\n'
            : '';
        return ChatMessage(
          text:
              'I can help you reschedule **${task.title}**.\n\n${currentTime}Estimated duration: ${task.estimatedMinutes} minutes\n\nWhen would you like to move it to? You can say:\n• "Tomorrow at 2 PM"\n• "Later today"\n• "Next week"',
          isAI: true,
          timestamp: DateTime.now(),
          relatedTask: task,
          suggestions: [
            'Move to tomorrow',
            'Move to later today',
            'Cancel reschedule',
          ],
        );
      } else {
        return ChatMessage(
          text:
              'I can help you reschedule tasks. Which task would you like to move?\n\nYou can say:\n• "Reschedule my math assignment"\n• "Move chemistry quiz"\n• "Change history reading"',
          isAI: true,
          timestamp: DateTime.now(),
          suggestions: tasks.map((t) => 'Reschedule ${t.title}').toList(),
        );
      }
    } else if (lowerInput.contains('schedule') ||
        lowerInput.contains('show') ||
        lowerInput.contains('list')) {
      return ChatMessage(
        text:
            'Here\'s your schedule for today:\n\n${_formatSchedule()}\n\nYou have ${tasks.length} tasks scheduled. Would you like me to help you optimize your schedule?',
        isAI: true,
        timestamp: DateTime.now(),
        showTasks: true,
        suggestions: [
          'Optimize schedule',
          'Add a break',
          'Show warnings',
        ],
      );
    } else if (lowerInput.contains('warning') ||
        lowerInput.contains('alert') ||
        lowerInput.contains('deadline')) {
      final urgentTasks = tasks
          .where((t) => t.priority == TaskPriority.urgent || t.isOverdue)
          .toList();

      if (urgentTasks.isNotEmpty) {
        return ChatMessage(
          text:
              '⚠️ **Urgent Alert**\n\nYou have ${urgentTasks.length} urgent task(s):\n\n${urgentTasks.map((t) => '• ${t.title} - Due ${DateFormat('h:mm a').format(t.deadline)}').join('\n')}\n\nI recommend prioritizing these tasks. Would you like me to reschedule other tasks to make room?',
          isAI: true,
          timestamp: DateTime.now(),
          showTasks: true,
          suggestions: [
            'Reschedule other tasks',
            'Focus on urgent tasks',
            'Show full schedule',
          ],
        );
      } else {
        return ChatMessage(
          text:
              'Great news! You don\'t have any urgent deadlines right now. Your schedule looks manageable. Keep up the good work! 🎉',
          isAI: true,
          timestamp: DateTime.now(),
        );
      }
    } else if (lowerInput.contains('help') || lowerInput.contains('how')) {
      return ChatMessage(
        text:
            'I can help you with:\n\n📅 **Planning**\n• "What should I study now?"\n• "Show my schedule"\n• "Optimize my day"\n\n🔄 **Rescheduling**\n• "Reschedule my math assignment"\n• "Move chemistry quiz to tomorrow"\n• "Change history reading time"\n\n⚠️ **Warnings**\n• "Show warnings"\n• "Any urgent tasks?"\n• "Check deadlines"\n\nJust ask me naturally!',
        isAI: true,
        timestamp: DateTime.now(),
        suggestions: [
          'What should I study now?',
          'Show my schedule',
          'Check for warnings',
        ],
      );
    } else {
      // Default friendly response
      return ChatMessage(
        text:
            'I understand! Let me help you with that. You can ask me to:\n\n• Plan your study schedule\n• Reschedule tasks\n• Get suggestions on what to study\n• Check for urgent deadlines\n\nWhat would you like to do?',
        isAI: true,
        timestamp: DateTime.now(),
        suggestions: [
          'What should I study now?',
          'Show my schedule',
          'Reschedule a task',
        ],
      );
    }
  }

  Task? _findTaskInInput(String input) {
    final lowerInput = input.toLowerCase();
    for (var task in _studentActionableTasks) {
      if (lowerInput.contains(task.title.toLowerCase()) ||
          lowerInput.contains(task.courseName.toLowerCase())) {
        return task;
      }
    }
    return null;
  }

  String _formatSchedule() {
    final sortedTasks = List<Task>.from(_studentActionableTasks)
      ..sort((a, b) => (a.scheduledTime ?? DateTime.now())
          .compareTo(b.scheduledTime ?? DateTime.now()));

    if (sortedTasks.isEmpty) {
      return 'No actionable unfinished tasks are available to schedule.';
    }

    return sortedTasks.map((task) {
      final time = task.scheduledTime != null
          ? DateFormat('h:mm a').format(task.scheduledTime!)
          : 'Not scheduled';
      return '• $time - ${task.title} (${task.courseName})';
    }).join('\n');
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = Colors.transparent;
    final cardBg = isDark ? const Color(0xFF111827) : const Color(0xFFF4F7FC);
    final borderColor =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : AppTheme.darkText;
    final suggestions =
        _messages.isNotEmpty ? _messages.last.suggestions : <String>[];
    final root = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.smart_toy_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Study Assistant',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: textColor),
                  ),
                  const SizedBox(height: 2),
                  const Row(
                    children: [
                      Icon(Icons.circle, size: 9, color: AppTheme.successGreen),
                      SizedBox(width: 6),
                      Text('Online & Ready',
                          style: TextStyle(
                              color: AppTheme.successGreen,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                return _buildChatMessage(_messages[index]);
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (suggestions.isNotEmpty) ...[
          Text(
            'Try asking:',
            style: TextStyle(
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: suggestions.take(4).map((s) {
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 80) / 2,
                child: OutlinedButton(
                  onPressed: () => _sendMessage(s),
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        isDark ? const Color(0xFF111827) : Colors.white,
                    side: BorderSide(color: borderColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                        color: textColor, fontWeight: FontWeight.w600),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Ask me anything about your studies...',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF111827) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                style: TextStyle(color: textColor),
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () => _sendMessage(_messageController.text),
                icon: const Icon(Icons.send_outlined, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );

    return Scaffold(
      appBar: widget.openDrawer == null
          ? null
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.openDrawer,
              ),
              title: const Text('AI Assistant'),
            ),
      backgroundColor: pageBg,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: root,
      ),
    );
  }

  Widget _buildChatMessage(ChatMessage message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aiBubbleColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment:
              message.isAI ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            child: Column(
              crossAxisAlignment: message.isAI
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                // Message Bubble
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: message.isAI ? null : AppTheme.primaryGradient,
                    color: message.isAI ? aiBubbleColor : null,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(message.isAI ? 16 : 4),
                      bottomRight: Radius.circular(message.isAI ? 4 : 16),
                    ),
                    border: message.isAI
                        ? Border.all(color: const Color(0xFFE2E8F0))
                        : null,
                    boxShadow: message.isAI ? null : AppTheme.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.isAI)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 12,
                                color: AppTheme.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'AI Assistant',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      if (message.isAI) const SizedBox(height: 8),
                      message.isAI
                          ? _buildMessageText(message.text)
                          : _buildUserMessageText(message.text),
                    ],
                  ),
                ),

                // Related Task Card
                if (message.relatedTask != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.75,
                    child: TaskCard(
                      task: message.relatedTask!,
                      onReschedule: () {
                        _sendMessage(
                            'Reschedule ${message.relatedTask!.title}');
                      },
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          AppConstants.routeTaskExecution,
                          arguments: message.relatedTask!,
                        );
                      },
                    ),
                  ),
                ],

                // Tasks List
                if (message.showTasks) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.75,
                    child: Column(
                      children: _studentActionableTasks.map((task) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TaskCard(
                            task: task,
                            onReschedule: () {
                              _sendMessage('Reschedule ${task.title}');
                            },
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                AppConstants.routeTaskExecution,
                                arguments: task,
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageText(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Parse markdown-like formatting
    final parts = <TextSpan>[];
    final regex = RegExp(r'(\*\*.*?\*\*|•)');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      // Add text before match
      if (match.start > lastIndex) {
        parts.add(TextSpan(
          text: text.substring(lastIndex, match.start),
        ));
      }

      // Add formatted match
      final matchedText = match.group(0)!;
      if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
        parts.add(TextSpan(
          text: matchedText.substring(2, matchedText.length - 2),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ));
      } else if (matchedText == '•') {
        parts.add(const TextSpan(text: '• '));
      } else {
        parts.add(TextSpan(text: matchedText));
      }

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      parts.add(TextSpan(text: text.substring(lastIndex)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: isDark ? Colors.white : AppTheme.darkText,
          fontSize: 14,
          height: 1.5,
        ),
        children: parts.isEmpty ? [TextSpan(text: text)] : parts,
      ),
    );
  }

  Widget _buildUserMessageText(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.white,
        fontSize: 14,
        height: 1.5,
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 12,
                color: AppTheme.white,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTypingDot(0),
                  _buildTypingDot(1),
                  _buildTypingDot(2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return AnimatedBuilder(
      animation: _typingAnimationController,
      builder: (context, child) {
        final delay = index * 0.2;
        final animatedValue =
            ((_typingAnimationController.value + delay) % 1.0);
        final opacity = 0.3 + (0.7 * (0.5 - (animatedValue - 0.5).abs()) * 2);

        return Container(
          width: 8,
          height: 8,
          margin: EdgeInsets.only(
            right: index < 2 ? 4 : 0,
          ),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(opacity.clamp(0.3, 1.0)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class ChatMessage {
  final String text;
  final bool isAI;
  final DateTime timestamp;
  final List<String> suggestions;
  final Task? relatedTask;
  final bool showTasks;

  ChatMessage({
    required this.text,
    required this.isAI,
    required this.timestamp,
    this.suggestions = const [],
    this.relatedTask,
    this.showTasks = false,
  });
}
