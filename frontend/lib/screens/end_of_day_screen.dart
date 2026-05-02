import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/task.dart';
import '../widgets/gradient_card.dart';

class EndOfDayScreen extends StatelessWidget {
  EndOfDayScreen({super.key});
  
  // Mock data
  final int _completedTasks = 7;
  final int _pendingTasks = 3;
  final int _totalFocusMinutes = 240; // 4 hours
  final double _productivityScore = 8.5;
  
  final List<Task> _completed = [
    Task(
      id: '1',
      title: 'Math Assignment 5',
      deadline: DateTime.now(),
      courseId: 'math',
      courseName: 'Mathematics',
      status: TaskStatus.completed,
      estimatedMinutes: 120,
      completedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Task(
      id: '2',
      title: 'History Reading',
      deadline: DateTime.now(),
      courseId: 'hist',
      courseName: 'History',
      status: TaskStatus.completed,
      estimatedMinutes: 60,
      completedAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];
  
  final List<Task> _pending = [
    Task(
      id: '3',
      title: 'Chemistry Lab Report',
      deadline: DateTime.now().add(const Duration(days: 1)),
      courseId: 'chem',
      courseName: 'Chemistry',
      status: TaskStatus.pending,
      estimatedMinutes: 90,
    ),
  ];
  
  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
=======
    final theme = Theme.of(context);
    final mutedText = theme.colorScheme.onSurface.withOpacity(0.7);
    final progressTrack = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHighest
        : AppTheme.lightGray;
>>>>>>> origin/continue
    final completionRate = _completedTasks / (_completedTasks + _pendingTasks);
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        title: const Text('End of Day Review'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Card
              GradientCard(
                child: Column(
                  children: [
                    const Text(
                      'Great Work Today!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      DateFormat('EEEE, MMMM d').format(DateTime.now()),
                      style: TextStyle(
                        fontSize: 16,
<<<<<<< HEAD
                        color: AppTheme.darkText.withOpacity(0.7),
=======
                        color: mutedText,
>>>>>>> origin/continue
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
<<<<<<< HEAD
=======
                          context,
>>>>>>> origin/continue
                          'Completed',
                          '$_completedTasks',
                          Icons.check_circle,
                          AppTheme.successGreen,
                        ),
                        _buildStatItem(
<<<<<<< HEAD
=======
                          context,
>>>>>>> origin/continue
                          'Pending',
                          '$_pendingTasks',
                          Icons.pending,
                          AppTheme.warningOrange,
                        ),
                        _buildStatItem(
<<<<<<< HEAD
=======
                          context,
>>>>>>> origin/continue
                          'Focus Time',
                          '${_totalFocusMinutes ~/ 60}h',
                          Icons.timer,
                          AppTheme.primaryBlue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Completion Progress
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Task Completion',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${(completionRate * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: completionRate,
<<<<<<< HEAD
                        backgroundColor: AppTheme.lightGray,
=======
                        backgroundColor: progressTrack,
>>>>>>> origin/continue
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Completed Tasks
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: AppTheme.successGreen,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Completed Tasks',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
<<<<<<< HEAD
                      ..._completed.map((task) => _buildTaskItem(task, true)),
=======
                      ..._completed.map(
                        (task) => _buildTaskItem(context, task, true),
                      ),
>>>>>>> origin/continue
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Pending Tasks
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.pending,
                            color: AppTheme.warningOrange,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Pending Tasks',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
<<<<<<< HEAD
                      ..._pending.map((task) => _buildTaskItem(task, false)),
=======
                      ..._pending.map(
                        (task) => _buildTaskItem(context, task, false),
                      ),
>>>>>>> origin/continue
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Focus Summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Focus Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFocusStat(
<<<<<<< HEAD
=======
                              context,
>>>>>>> origin/continue
                              'Total Focus',
                              '${_totalFocusMinutes ~/ 60}h ${_totalFocusMinutes % 60}m',
                              Icons.timer,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppTheme.mediumGray,
                          ),
                          Expanded(
                            child: _buildFocusStat(
<<<<<<< HEAD
=======
                              context,
>>>>>>> origin/continue
                              'Productivity',
                              '$_productivityScore/10',
                              Icons.trending_up,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // AI Recommendations
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: AppTheme.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Recommendations for Tomorrow',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildRecommendation(
<<<<<<< HEAD
=======
                        context,
>>>>>>> origin/continue
                        'Start with Chemistry Lab Report',
                        'This is your highest priority task for tomorrow. Schedule it for the morning when you\'re most focused.',
                        Icons.priority_high,
                      ),
                      const SizedBox(height: 12),
                      _buildRecommendation(
<<<<<<< HEAD
=======
                        context,
>>>>>>> origin/continue
                        'Take a 15-minute break between tasks',
                        'You worked for 4 hours today. Remember to take breaks to maintain productivity.',
                        Icons.coffee,
                      ),
                      const SizedBox(height: 12),
                      _buildRecommendation(
<<<<<<< HEAD
=======
                        context,
>>>>>>> origin/continue
                        'Review completed tasks',
                        'Great job completing 7 tasks! Review what you learned to reinforce the material.',
                        Icons.rate_review,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Action Button
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to tomorrow's planner
                },
                icon: const Icon(Icons.calendar_today),
                label: const Text('Plan Tomorrow'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
<<<<<<< HEAD
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
=======
  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final subtleText = Theme.of(context).colorScheme.onSurface.withOpacity(0.65);
>>>>>>> origin/continue
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
<<<<<<< HEAD
            color: AppTheme.mediumGray,
=======
            color: subtleText,
>>>>>>> origin/continue
          ),
        ),
      ],
    );
  }
  
<<<<<<< HEAD
  Widget _buildTaskItem(Task task, bool isCompleted) {
=======
  Widget _buildTaskItem(
    BuildContext context,
    Task task,
    bool isCompleted,
  ) {
    final subtleText = Theme.of(context).colorScheme.onSurface.withOpacity(0.65);
>>>>>>> origin/continue
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppTheme.successGreen.withOpacity(0.1)
            : AppTheme.warningOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? AppTheme.successGreen : AppTheme.warningOrange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                Text(
                  task.courseName,
                  style: TextStyle(
                    fontSize: 12,
<<<<<<< HEAD
                    color: AppTheme.mediumGray,
=======
                    color: subtleText,
>>>>>>> origin/continue
                  ),
                ),
              ],
            ),
          ),
          if (isCompleted && task.completedAt != null)
            Text(
              DateFormat('h:mm a').format(task.completedAt!),
              style: TextStyle(
                fontSize: 12,
<<<<<<< HEAD
                color: AppTheme.mediumGray,
=======
                color: subtleText,
>>>>>>> origin/continue
              ),
            ),
        ],
      ),
    );
  }
  
<<<<<<< HEAD
  Widget _buildFocusStat(String label, String value, IconData icon) {
=======
  Widget _buildFocusStat(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final subtleText = Theme.of(context).colorScheme.onSurface.withOpacity(0.65);
>>>>>>> origin/continue
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryBlue),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
<<<<<<< HEAD
            color: AppTheme.mediumGray,
=======
            color: subtleText,
>>>>>>> origin/continue
          ),
        ),
      ],
    );
  }
  
<<<<<<< HEAD
  Widget _buildRecommendation(String title, String description, IconData icon) {
=======
  Widget _buildRecommendation(
    BuildContext context,
    String title,
    String description,
    IconData icon,
  ) {
    final mutedText = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
>>>>>>> origin/continue
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
<<<<<<< HEAD
                    color: AppTheme.darkText.withOpacity(0.7),
=======
                    color: mutedText,
>>>>>>> origin/continue
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
