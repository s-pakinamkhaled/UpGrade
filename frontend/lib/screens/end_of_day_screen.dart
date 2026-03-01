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
  
  List<Task> _completed = [
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
  
  List<Task> _pending = [
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
    final completionRate = _completedTasks / (_completedTasks + _pendingTasks);
    
    return Scaffold(
      appBar: AppBar(
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
                        color: AppTheme.darkText.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          'Completed',
                          '$_completedTasks',
                          Icons.check_circle,
                          AppTheme.successGreen,
                        ),
                        _buildStatItem(
                          'Pending',
                          '$_pendingTasks',
                          Icons.pending,
                          AppTheme.warningOrange,
                        ),
                        _buildStatItem(
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
                        backgroundColor: AppTheme.lightGray,
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
                      ..._completed.map((task) => _buildTaskItem(task, true)),
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
                      ..._pending.map((task) => _buildTaskItem(task, false)),
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
                        'Start with Chemistry Lab Report',
                        'This is your highest priority task for tomorrow. Schedule it for the morning when you\'re most focused.',
                        Icons.priority_high,
                      ),
                      const SizedBox(height: 12),
                      _buildRecommendation(
                        'Take a 15-minute break between tasks',
                        'You worked for 4 hours today. Remember to take breaks to maintain productivity.',
                        Icons.coffee,
                      ),
                      const SizedBox(height: 12),
                      _buildRecommendation(
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
  
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
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
            color: AppTheme.mediumGray,
          ),
        ),
      ],
    );
  }
  
  Widget _buildTaskItem(Task task, bool isCompleted) {
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
                    color: AppTheme.mediumGray,
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
                color: AppTheme.mediumGray,
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildFocusStat(String label, String value, IconData icon) {
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
            color: AppTheme.mediumGray,
          ),
        ),
      ],
    );
  }
  
  Widget _buildRecommendation(String title, String description, IconData icon) {
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
                    color: AppTheme.darkText.withOpacity(0.7),
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
