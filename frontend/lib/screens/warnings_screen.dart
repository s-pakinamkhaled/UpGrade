import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/gradient_card.dart';

class WarningsScreen extends StatelessWidget {
  const WarningsScreen({super.key});
  
  // Mock data
  final List<Warning> _warnings = const [
    Warning(
      type: WarningType.missedTask,
      title: 'Missed Task Alert',
      message: 'You missed "Chemistry Quiz Prep" scheduled for 2 hours ago',
      severity: WarningSeverity.high,
      action: 'Reschedule now',
    ),
    Warning(
      type: WarningType.deadline,
      title: 'Upcoming Deadline',
      message: 'Math Assignment 5 is due in 5 hours',
      severity: WarningSeverity.urgent,
      action: 'Prioritize this task',
    ),
    Warning(
      type: WarningType.workload,
      title: 'Heavy Workload',
      message: 'You have 8 tasks scheduled for today. Consider rescheduling some.',
      severity: WarningSeverity.medium,
      action: 'Review schedule',
    ),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Warnings & Alerts'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          GradientCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.warningOrange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Proactive Alerts',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Stay ahead of your schedule',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Warnings List
          ..._warnings.map((warning) => _buildWarningCard(warning)),
          
          const SizedBox(height: 16),
          
          // Suggested Actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Suggested Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActionCard(
                    'Reschedule Overdue Tasks',
                    'Move missed tasks to tomorrow',
                    Icons.schedule,
                    AppTheme.primaryBlue,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    'Prioritize Urgent Tasks',
                    'Focus on deadlines coming soon',
                    Icons.priority_high,
                    AppTheme.warningOrange,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    'Break Down Large Tasks',
                    'Split heavy tasks into smaller chunks',
                    Icons.breakfast_dining,
                    AppTheme.secondaryPurple,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWarningCard(Warning warning) {
    Color severityColor;
    IconData icon;
    
    switch (warning.severity) {
      case WarningSeverity.urgent:
        severityColor = AppTheme.errorRed;
        icon = Icons.error;
        break;
      case WarningSeverity.high:
        severityColor = AppTheme.warningOrange;
        icon = Icons.warning;
        break;
      case WarningSeverity.medium:
        severityColor = AppTheme.primaryBlue;
        icon = Icons.info;
        break;
      case WarningSeverity.low:
        severityColor = AppTheme.mediumGray;
        icon = Icons.info_outline;
        break;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: severityColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        warning.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        warning.message,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.darkText.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Handle action
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: severityColor,
                      side: BorderSide(color: severityColor),
                    ),
                    child: Text(warning.action),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    // Dismiss warning
                  },
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        // Handle action
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
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
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.darkText.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

class Warning {
  final WarningType type;
  final String title;
  final String message;
  final WarningSeverity severity;
  final String action;
  
  const Warning({
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    required this.action,
  });
}

enum WarningType {
  missedTask,
  deadline,
  workload,
  burnout,
}

enum WarningSeverity {
  low,
  medium,
  high,
  urgent,
}
