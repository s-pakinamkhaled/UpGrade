import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/settings_provider.dart';
import '../widgets/dashboard_secondary_shell.dart';
import '../widgets/upgrade_visual_system.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return LayoutBuilder(
          builder: (context, constraints) {
            final rem = UpGradeRem(constraints.maxWidth);
            return DecoratedBox(
              decoration: UpGradePageDecor.pageBackground(isDark),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(rem.space(1.15)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UpGradeGradientTitle(
                      'Privacy Settings',
                      rem: rem,
                      isDark: isDark,
                    ),
                    SizedBox(height: rem.space(0.35)),
                    UpGradeMutedSubtitle(
                      'Manage your data and privacy preferences',
                      rem: rem,
                      isDark: isDark,
                    ),
                    SizedBox(height: rem.space(0.9)),
                    UpGradeGradientFrameCard(
                      rem: rem,
                      isDark: isDark,
                      child: Column(
                        children: [
                          _privacyRow(
                            context: context,
                            icon: Icons.dark_mode_outlined,
                            iconBg: const Color(0xFFE2E8F0),
                            iconColor: const Color(0xFF334155),
                            title: 'Dark Mode',
                            subtitle: 'Use a darker theme for this interface',
                            value: settings.themeMode == ThemeMode.dark,
                            onChanged: settings.toggleTheme,
                          ),
                          _divider(context),
                          _privacyRow(
                            context: context,
                            icon: Icons.notifications_none_rounded,
                            iconBg: const Color(0xFFE6EFFC),
                            iconColor: AppTheme.primaryBlue,
                            title: 'Push Notifications',
                            subtitle:
                                'Receive alerts about tasks and deadlines',
                            value: settings.notificationsEnabled == true,
                            onChanged: settings.setNotificationsEnabled,
                          ),
                          _divider(context),
                          _privacyRow(
                            context: context,
                            icon: Icons.visibility_outlined,
                            iconBg: const Color(0xFFF3E8FF),
                            iconColor: const Color(0xFF9333EA),
                            title: 'Focus Tracking',
                            subtitle: 'Allow AI to track your study sessions',
                            value: settings.aiSuggestionsEnabled == true,
                            onChanged: settings.setAiSuggestionsEnabled,
                          ),
                          _divider(context),
                          _preferenceChipRow<StudyStyle>(
                            context: context,
                            icon: Icons.menu_book_outlined,
                            iconBg: const Color(0xFFDCFCE7),
                            iconColor: const Color(0xFF16A34A),
                            title: 'Study Style',
                            subtitle:
                                'How the AI shapes plans and study group matching',
                            options: const [
                              (label: 'Visual', value: StudyStyle.visual),
                              (label: 'Reading', value: StudyStyle.reading),
                              (label: 'Practice', value: StudyStyle.practice),
                            ],
                            selected: settings.studyStyle,
                            onSelected: settings.setStudyStyle,
                          ),
                          _divider(context),
                          _preferenceChipRow<DifficultyLevel>(
                            context: context,
                            icon: Icons.speed_outlined,
                            iconBg: const Color(0xFFFFE4E6),
                            iconColor: const Color(0xFFE11D48),
                            title: 'Planner Difficulty',
                            subtitle:
                                'How demanding your daily study load should feel',
                            options: const [
                              (label: 'Easy', value: DifficultyLevel.easy),
                              (
                                label: 'Balanced',
                                value: DifficultyLevel.balanced,
                              ),
                              (
                                label: 'Challenging',
                                value: DifficultyLevel.challenging,
                              ),
                            ],
                            selected: settings.difficulty,
                            onSelected: settings.setDifficulty,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return DashboardSecondaryShell(
      narrow: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Privacy Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        body: content,
      ),
      wideBody: content,
    );
  }

  Widget _divider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 20,
      thickness: 1,
      color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
    );
  }

  Color _iconBackground(Color light, bool isDark) {
    if (!isDark) return light;
    return Color.alphaBlend(
      light.withOpacity(0.22),
      const Color(0xFF1F2937),
    );
  }

  Widget _settingsSwitch({
    required bool value,
    required bool isDark,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchTheme(
      data: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? const Color(0xFFF8FAFC) : Colors.white;
          }
          return isDark ? const Color(0xFFCBD5E1) : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? AppTheme.primaryBlue : const Color(0xFF111827);
          }
          return isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return isDark ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF);
        }),
      ),
      child: Switch(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _preferenceChipRow<T>({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<({String label, T value})> options,
    required T selected,
    required Future<void> Function(T value) onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _iconBackground(iconBg, isDark),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in options)
                    ChoiceChip(
                      label: Text(option.label),
                      selected: option.value == selected,
                      onSelected: (_) => onSelected(option.value),
                      backgroundColor: isDark
                          ? const Color(0xFF1F2937)
                          : const Color(0xFFF8FAFC),
                      selectedColor: isDark
                          ? AppTheme.primaryBlue.withOpacity(0.45)
                          : AppTheme.primaryBlue.withOpacity(0.18),
                      side: BorderSide(
                        color: option.value == selected
                            ? AppTheme.primaryBlue.withOpacity(0.55)
                            : (isDark
                                ? const Color(0xFF4B5563)
                                : const Color(0xFFE2E8F0)),
                      ),
                      labelStyle: TextStyle(
                        fontWeight: option.value == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _privacyRow({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required Future<void> Function(bool) onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _iconBackground(iconBg, isDark),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              _settingsSwitch(
                value: value,
                isDark: isDark,
                onChanged: (v) => onChanged(v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
