import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../models/task.dart';
import '../widgets/task_card.dart';
import '../services/api_service.dart';

class AIChatbotScreen extends StatefulWidget {
  const AIChatbotScreen({super.key});
  
  @override
  State<AIChatbotScreen> createState() => _AIChatbotScreenState();
}

class _AIChatbotScreenState extends State<AIChatbotScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  late AnimationController _typingAnimationController;
  
  // Mock data - in real app, this would come from a service
  final List<Task> _todayTasks = [
    Task(
      id: '1',
      title: 'Complete Math Assignment 5',
      description: 'Chapters 3-4, problems 1-20',
      deadline: DateTime.now().add(const Duration(hours: 5)),
      courseId: 'math101',
      courseName: 'Mathematics 101',
      priority: TaskPriority.high,
      status: TaskStatus.pending,
      estimatedMinutes: 120,
      scheduledTime: DateTime.now().add(const Duration(hours: 2)),
    ),
    Task(
      id: '2',
      title: 'Read History Chapter 8',
      deadline: DateTime.now().add(const Duration(days: 2)),
      courseId: 'hist201',
      courseName: 'World History',
      priority: TaskPriority.medium,
      status: TaskStatus.pending,
      estimatedMinutes: 60,
      scheduledTime: DateTime.now().add(const Duration(hours: 4)),
    ),
    Task(
      id: '3',
      title: 'Prepare for Chemistry Quiz',
      deadline: DateTime.now().add(const Duration(days: 1)),
      courseId: 'chem101',
      courseName: 'Chemistry',
      priority: TaskPriority.urgent,
      status: TaskStatus.pending,
      estimatedMinutes: 90,
      scheduledTime: DateTime.now().add(const Duration(hours: 6)),
    ),
  ];
  
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
    _messages.add(ChatMessage(
      text: 'Hi! I\'m your AI study assistant. I\'ve organized your day with 3 tasks. You can ask me to:\n\n• Reschedule tasks\n• Suggest what to study now\n• Get warnings about deadlines\n• Modify your schedule\n\nWhat would you like to do?',
      isAI: true,
      timestamp: DateTime.now(),
      suggestions: [
        'What should I study now?',
        'Reschedule my math assignment',
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
      // Prepare conversation history
      final history = _messages.take(_messages.length - 1).map((msg) {
        return {
          'role': msg.isAI ? 'assistant' : 'user',
          'content': msg.text,
        };
      }).toList();
      
      // Prepare student context
      final studentContext = {
        'name': 'Student',  // In real app, get from user profile
        'tasks': _todayTasks.map((task) => {
          'title': task.title,
          'priority': task.priority.name,
          'deadline': task.deadline.toIso8601String(),
          'courseName': task.courseName,
        }).toList(),
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
              text: response['message'] ?? 'Sorry, I couldn\'t generate a response.',
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
      print('Error calling AI API: $e');
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
    
    // Natural language processing simulation
    if (lowerInput.contains('study now') || lowerInput.contains('what should') || lowerInput.contains('next')) {
      final nextTask = _todayTasks.firstWhere(
        (task) => task.scheduledTime != null && 
                  task.scheduledTime!.isAfter(DateTime.now()),
        orElse: () => _todayTasks.first,
      );
      
      return ChatMessage(
        text: 'Based on your schedule, I recommend starting with **${nextTask.title}**.\n\nIt\'s scheduled for ${DateFormat('h:mm a').format(nextTask.scheduledTime!)} and will take about ${nextTask.estimatedMinutes} minutes. This is a ${nextTask.priority.label.toLowerCase()} priority task.\n\nWould you like me to start a focus session for this?',
        isAI: true,
        timestamp: DateTime.now(),
        relatedTask: nextTask,
        suggestions: [
          'Start focus session',
          'Reschedule this task',
          'Show all tasks',
        ],
      );
    } else if (lowerInput.contains('reschedule') || lowerInput.contains('move') || lowerInput.contains('change')) {
      final task = _findTaskInInput(userInput);
      
      if (task != null) {
        return ChatMessage(
          text: 'I can help you reschedule **${task.title}**.\n\nCurrent time: ${DateFormat('h:mm a').format(task.scheduledTime!)}\nEstimated duration: ${task.estimatedMinutes} minutes\n\nWhen would you like to move it to? You can say:\n• "Tomorrow at 2 PM"\n• "Later today"\n• "Next week"',
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
          text: 'I can help you reschedule tasks. Which task would you like to move?\n\nYou can say:\n• "Reschedule my math assignment"\n• "Move chemistry quiz"\n• "Change history reading"',
          isAI: true,
          timestamp: DateTime.now(),
          suggestions: _todayTasks.map((t) => 'Reschedule ${t.title}').toList(),
        );
      }
    } else if (lowerInput.contains('schedule') || lowerInput.contains('show') || lowerInput.contains('list')) {
      return ChatMessage(
        text: 'Here\'s your schedule for today:\n\n${_formatSchedule()}\n\nYou have ${_todayTasks.length} tasks scheduled. Would you like me to help you optimize your schedule?',
        isAI: true,
        timestamp: DateTime.now(),
        showTasks: true,
        suggestions: [
          'Optimize schedule',
          'Add a break',
          'Show warnings',
        ],
      );
    } else if (lowerInput.contains('warning') || lowerInput.contains('alert') || lowerInput.contains('deadline')) {
      final urgentTasks = _todayTasks.where((t) => 
        t.priority == TaskPriority.urgent || t.isOverdue
      ).toList();
      
      if (urgentTasks.isNotEmpty) {
        return ChatMessage(
          text: '⚠️ **Urgent Alert**\n\nYou have ${urgentTasks.length} urgent task(s):\n\n${urgentTasks.map((t) => '• ${t.title} - Due ${DateFormat('h:mm a').format(t.deadline)}').join('\n')}\n\nI recommend prioritizing these tasks. Would you like me to reschedule other tasks to make room?',
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
          text: 'Great news! You don\'t have any urgent deadlines right now. Your schedule looks manageable. Keep up the good work! 🎉',
          isAI: true,
          timestamp: DateTime.now(),
        );
      }
    } else if (lowerInput.contains('help') || lowerInput.contains('how')) {
      return ChatMessage(
        text: 'I can help you with:\n\n📅 **Planning**\n• "What should I study now?"\n• "Show my schedule"\n• "Optimize my day"\n\n🔄 **Rescheduling**\n• "Reschedule my math assignment"\n• "Move chemistry quiz to tomorrow"\n• "Change history reading time"\n\n⚠️ **Warnings**\n• "Show warnings"\n• "Any urgent tasks?"\n• "Check deadlines"\n\nJust ask me naturally!',
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
        text: 'I understand! Let me help you with that. You can ask me to:\n\n• Plan your study schedule\n• Reschedule tasks\n• Get suggestions on what to study\n• Check for urgent deadlines\n\nWhat would you like to do?',
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
    for (var task in _todayTasks) {
      if (lowerInput.contains(task.title.toLowerCase()) ||
          lowerInput.contains(task.courseName.toLowerCase())) {
        return task;
      }
    }
    return null;
  }
  
  String _formatSchedule() {
    final sortedTasks = List<Task>.from(_todayTasks)
      ..sort((a, b) => (a.scheduledTime ?? DateTime.now())
          .compareTo(b.scheduledTime ?? DateTime.now()));
    
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: AppTheme.softShadow,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppTheme.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'AI Assistant',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _sendMessage('help');
            },
            tooltip: 'Help',
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick Stats Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.white,
              boxShadow: AppTheme.softShadow,
            ),
            child: Row(
              children: [
                _buildQuickStat(
                  '${_todayTasks.length}',
                  'Tasks',
                  AppTheme.primaryBlue,
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: AppTheme.mediumGray.withOpacity(0.3),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                _buildQuickStat(
                  '${_todayTasks.where((t) => t.priority == TaskPriority.urgent).length}',
                  'Urgent',
                  AppTheme.errorRed,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AppTheme.softGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.successGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Online',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkText.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Chat Messages
          Expanded(
            child: Container(
              color: AppTheme.lightGray,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isTyping) {
                    return _buildTypingIndicator();
                  }
                  
                  final message = _messages[index];
                  return _buildChatMessage(message);
                },
              ),
            ),
          ),
          
          // Suggestions Bar (if last message has suggestions)
          if (_messages.isNotEmpty && _messages.last.suggestions.isNotEmpty)
            _buildSuggestionsBar(_messages.last.suggestions),
          
          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.white,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.lightGray,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Ask me anything...',
                          hintStyle: TextStyle(
                            color: AppTheme.mediumGray,
                            fontSize: 14,
                          ),
                          filled: false,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.auto_awesome,
                            size: 18,
                            color: AppTheme.primaryBlue.withOpacity(0.6),
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _sendMessage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _sendMessage(_messageController.text),
                        borderRadius: BorderRadius.circular(28),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.send_rounded,
                            color: AppTheme.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickStat(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.mediumGray,
          ),
        ),
      ],
    );
  }
  
  Widget _buildChatMessage(ChatMessage message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: message.isAI ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: Column(
              crossAxisAlignment: message.isAI
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                // Message Bubble
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: message.isAI
                        ? null
                        : AppTheme.primaryGradient,
                    color: message.isAI ? AppTheme.white : null,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(message.isAI ? 20 : 4),
                      bottomRight: Radius.circular(message.isAI ? 4 : 20),
                    ),
                    boxShadow: AppTheme.softShadow,
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
                        _sendMessage('Reschedule ${message.relatedTask!.title}');
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
                      children: _todayTasks.map((task) {
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
          color: AppTheme.darkText,
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.softShadow,
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
        final animatedValue = ((_typingAnimationController.value + delay) % 1.0);
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
  
  Widget _buildSuggestionsBar(List<String> suggestions) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        border: Border(
          top: BorderSide(
            color: AppTheme.mediumGray.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => _sendMessage(suggestion),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppTheme.softGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    suggestion,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
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
