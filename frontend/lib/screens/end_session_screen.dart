import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/task.dart';
import '../providers/classroom_provider.dart';

class EndSessionScreen extends StatelessWidget {
  final VoidCallback onContinue;
  final Future<void> Function() onEndAndSignOut;

  const EndSessionScreen({
    super.key,
    required this.onContinue,
    required this.onEndAndSignOut,
  });

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _formatStudyTimeMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h <= 0) return '${m}m';
    return '${h}h ${m}m';
  }

  int _computeStudyTimeMinutes(List<Task> tasks) {
    // Approximation for the UI: sum estimated minutes for completed tasks.
    return tasks
        .where((t) => t.status == TaskStatus.completed)
        .fold<int>(0, (sum, t) => sum + t.estimatedMinutes);
  }

  int _computeStreakDays(List<Task> tasks) {
    // Simple streak based on consecutive days up to "today" where at least
    // one completed task exists on that day.
    final today = _dateOnly(DateTime.now());
    var streak = 0;
    for (var i = 0; i < 30; i++) {
      final day = today.subtract(Duration(days: i));
      final hasCompleted =
          tasks.any((t) => t.status == TaskStatus.completed && _dateOnly(t.deadline) == day);
      if (!hasCompleted) break;
      streak++;
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClassroomProvider>(
      builder: (context, provider, _) {
        final tasks = provider.tasks;
        final totalTasks = tasks.where((t) => t.status != TaskStatus.missed).length;
        final completedTasks = tasks.where((t) => t.status == TaskStatus.completed).length;

        final studyMinutes = _computeStudyTimeMinutes(tasks);
        final focusScore = totalTasks == 0
            ? 0
            : ((completedTasks / totalTasks) * 100).round().clamp(0, 100);

        final streakDays = _computeStreakDays(tasks);
        final badgeText = focusScore >= 85 ? 'High Productivity' : 'On Track';

        final tip =
            'Tip: Take a 15-minute break before your next study session for optimal performance';

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final bg = isDark ? theme.scaffoldBackgroundColor : Colors.white;
        final card = isDark ? theme.colorScheme.surface : Colors.white;
        final secondary = isDark ? const Color(0xFF9CA3AF) : AppTheme.mediumGray;
        final onSurface = theme.colorScheme.onSurface;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                    onPressed: onContinue,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTopSummary(
                          isDark: isDark,
                          onSurface: onSurface,
                          badgeText: badgeText,
                          focusScore: focusScore,
                        ),
                        const SizedBox(height: 16),
                        _buildStatCards(
                          context,
                          secondary: secondary,
                          studyMinutes: studyMinutes,
                          completedTasks: completedTasks,
                          totalTasks: totalTasks == 0 ? 1 : totalTasks,
                          isDark: isDark,
                          card: card,
                        ),
                        const SizedBox(height: 16),
                        _buildFocusBar(
                          focusScore: focusScore,
                          isDark: isDark,
                          onSurface: onSurface,
                        ),
                        const SizedBox(height: 16),
                        _buildAchievement(
                          onSurface: onSurface,
                          streakDays: streakDays,
                          isDark: isDark,
                          card: card,
                        ),
                        const SizedBox(height: 16),
                        _buildButtons(
                          isDark: isDark,
                          onContinue: onContinue,
                          onEndAndSignOut: onEndAndSignOut,
                        ),
                        const SizedBox(height: 16),
                        _buildTip(tip, secondary, isDark),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopSummary({
    required bool isDark,
    required Color onSurface,
    required String badgeText,
    required int focusScore,
  }) {
    final badgeBg = isDark ? const Color(0xFF1B5E20) : const Color(0xFFD1FAE5);
    final badgeFg = isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A);
    final title = focusScore >= 80 ? 'Excellent Session!' : 'Session Summary';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: onSurface,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: badgeFg,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards(
    BuildContext context, {
    required bool isDark,
    required Color card,
    required Color secondary,
    required int studyMinutes,
    required int completedTasks,
    required int totalTasks,
  }) {
    final studyTimeStr = _formatStudyTimeMinutes(studyMinutes);
    final doneStr = '$completedTasks/$totalTasks';

    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.timer_outlined,
            iconColor: AppTheme.primaryBlue,
            title: 'Study Time',
            value: studyTimeStr,
            secondary: secondary,
            card: card,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _statCard(
            icon: Icons.flag,
            iconColor: AppTheme.secondaryPurple,
            title: 'Tasks Done',
            value: doneStr,
            secondary: secondary,
            card: card,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required Color secondary,
    required Color card,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: secondary.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.08 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontSize: 13, color: secondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: iconColor,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusBar({
    required int focusScore,
    required bool isDark,
    required Color onSurface,
  }) {
    final percentText = '$focusScore%';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? themeSurface(isDark) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Focus Score',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                percentText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: onSurface.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 10,
              color: onSurface.withOpacity(0.12),
              child: FractionallySizedBox(
                widthFactor: (focusScore / 100).clamp(0.0, 1.0),
                child: Container(
                  color: isDark ? const Color(0xFF0B0F1A) : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Small helper: keeps the focus card background consistent in dark mode.
  static Color themeSurface(bool isDark) => isDark ? const Color(0xFF0F172A) : Colors.white;

  Widget _buildAchievement({
    required int streakDays,
    required Color onSurface,
    required bool isDark,
    required Color card,
  }) {
    final unlockedText =
        streakDays <= 0 ? 'Start your streak today!' : '$streakDays-day study streak! You\'re building great habits.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? card : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? onSurface.withOpacity(0.12) : const Color(0xFFFFEDD5)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFB923C), Color(0xFFF97316)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.emoji_events, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Achievement Unlocked!',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unlockedText,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF7C2D12),
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

  Widget _buildButtons({
    required bool isDark,
    required VoidCallback onContinue,
    required Future<void> Function() onEndAndSignOut,
  }) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(0),
                foregroundColor: Colors.white,
              ),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                height: 44,
                child: const Text(
                  'Continue Studying',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => onEndAndSignOut(),
              icon: const Icon(Icons.logout),
              label: const Text('End & Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorRed,
                side: const BorderSide(color: AppTheme.errorRed),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTip(String tip, Color secondary, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? secondary.withOpacity(0.16) : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: AppTheme.primaryBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(color: secondary, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

