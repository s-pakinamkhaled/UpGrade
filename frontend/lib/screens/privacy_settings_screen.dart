import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/settings_provider.dart';
import '../widgets/dashboard_secondary_shell.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          color: isDark ? const Color(0xFF0B1220) : const Color(0xFFF1F5F9),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy Settings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your data and privacy preferences',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? const Color(0xFF9CA3AF) : AppTheme.darkText.withOpacity(0.72),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111827) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
                    ),
                  ),
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
                      _divider(),
                      _privacyRow(
                        context: context,
                        icon: Icons.notifications_none_rounded,
                        iconBg: const Color(0xFFE6EFFC),
                        iconColor: AppTheme.primaryBlue,
                        title: 'Push Notifications',
                        subtitle: 'Receive alerts about tasks and deadlines',
                        value: settings.notificationsEnabled == true,
                        onChanged: settings.setNotificationsEnabled,
                      ),
                      _divider(),
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
                      _divider(),
                      _privacyRow(
                        context: context,
                        icon: Icons.shield_outlined,
                        iconBg: const Color(0xFFDCFCE7),
                        iconColor: const Color(0xFF16A34A),
                        title: 'Data Sharing',
                        subtitle: 'Share anonymized data to improve AI',
                        value: settings.dataSharingEnabled == true,
                        onChanged: settings.setDataSharingEnabled,
                      ),
                      _divider(),
                      _privacyRow(
                        context: context,
                        icon: Icons.lock_outline,
                        iconBg: const Color(0xFFFFE4E6),
                        iconColor: const Color(0xFFE11D48),
                        title: 'Two-Factor Authentication',
                        subtitle: 'Add extra security to your account',
                        value: settings.twoFactorEnabled == true,
                        onChanged: settings.setTwoFactorEnabled,
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

    return DashboardSecondaryShell(
      highlightRoute: AppConstants.routeProfile,
      narrow: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0B1220)
            : const Color(0xFFF1F5F9),
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

  Widget _divider() => const Divider(height: 20, thickness: 1);

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
            color: iconBg,
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
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              Switch(
                value: value,
                onChanged: (v) => onChanged(v),
                activeColor: Colors.white,
                activeTrackColor: const Color(0xFF111827),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFD1D5DB),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

