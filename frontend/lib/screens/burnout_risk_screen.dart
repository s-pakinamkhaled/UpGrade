import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/gradient_card.dart';

class BurnoutRiskScreen extends StatelessWidget {
  const BurnoutRiskScreen({super.key});
  
  // Mock data
  final double _burnoutScore = 0.65; // 65% risk
  final int _workloadIntensity = 8; // 1-10 scale
  final int _consecutiveDays = 7;
  final int _avgHoursPerDay = 6;
  
  String _getRiskLevel() {
    if (_burnoutScore >= 0.7) return 'High';
    if (_burnoutScore >= 0.4) return 'Medium';
    return 'Low';
  }
  
  Color _getRiskColor() {
    if (_burnoutScore >= 0.7) return AppTheme.errorRed;
    if (_burnoutScore >= 0.4) return AppTheme.warningOrange;
    return AppTheme.successGreen;
  }
  
  @override
  Widget build(BuildContext context) {
    final riskLevel = _getRiskLevel();
    final riskColor = _getRiskColor();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Burnout & Workload Risk'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Risk Score Card
              GradientCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: riskColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.health_and_safety,
                            color: riskColor,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Burnout Risk: $riskLevel',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: riskColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(_burnoutScore * 100).toInt()}% risk detected',
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
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 12,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _burnoutScore,
                          backgroundColor: AppTheme.lightGray,
                          valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                          minHeight: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Workload Intensity
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Workload Intensity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: List.generate(10, (index) {
                          return Expanded(
                            child: Container(
                              height: 8,
                              margin: EdgeInsets.only(
                                right: index < 9 ? 4 : 0,
                              ),
                              decoration: BoxDecoration(
                                color: index < _workloadIntensity
                                    ? (index < 5
                                        ? AppTheme.successGreen
                                        : index < 8
                                            ? AppTheme.warningOrange
                                            : AppTheme.errorRed)
                                    : AppTheme.lightGray,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$_workloadIntensity/10 - ${_workloadIntensity >= 8 ? "Very High" : _workloadIntensity >= 6 ? "High" : "Moderate"}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.darkText.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Risk Factors
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Risk Factors',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildRiskFactor(
                        'Consecutive Study Days',
                        '$_consecutiveDays days without rest',
                        Icons.calendar_today,
                        _consecutiveDays > 5 ? AppTheme.errorRed : AppTheme.warningOrange,
                      ),
                      const SizedBox(height: 12),
                      _buildRiskFactor(
                        'Average Daily Hours',
                        '$_avgHoursPerDay hours per day',
                        Icons.access_time,
                        _avgHoursPerDay > 6 ? AppTheme.errorRed : AppTheme.warningOrange,
                      ),
                      const SizedBox(height: 12),
                      _buildRiskFactor(
                        'Task Completion Rate',
                        'Below average this week',
                        Icons.trending_down,
                        AppTheme.warningOrange,
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
                            'AI Recommendations',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildRecommendation(
                        'Take a Break',
                        'You\'ve been studying for $_consecutiveDays consecutive days. Consider taking tomorrow off to recharge.',
                        Icons.spa,
                        AppTheme.successGreen,
                      ),
                      const SizedBox(height: 12),
                      _buildRecommendation(
                        'Reduce Daily Load',
                        'Try reducing your daily study hours from $_avgHoursPerDay to 4-5 hours to prevent burnout.',
                        Icons.timer_off,
                        AppTheme.primaryBlue,
                      ),
                      const SizedBox(height: 12),
                      _buildRecommendation(
                        'Schedule Rest Days',
                        'Plan 1-2 rest days per week to maintain long-term productivity.',
                        Icons.event_available,
                        AppTheme.secondaryPurple,
                      ),
                      const SizedBox(height: 12),
                      _buildRecommendation(
                        'Practice Mindfulness',
                        'Try 10-minute meditation sessions to reduce stress and improve focus.',
                        Icons.self_improvement,
                        AppTheme.warningOrange,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Action Buttons
              ElevatedButton.icon(
                onPressed: () {
                  // Implement rest day scheduling
                },
                icon: const Icon(Icons.event_available),
                label: const Text('Schedule Rest Day'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  // Show more recommendations
                },
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('View More Tips'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildRiskFactor(String title, String subtitle, IconData icon, Color color) {
    return Container(
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
        ],
      ),
    );
  }
  
  Widget _buildRecommendation(String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
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
