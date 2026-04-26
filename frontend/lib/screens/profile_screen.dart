import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/constants.dart';
import '../widgets/dashboard_secondary_shell.dart';
import '../widgets/gradient_card.dart';
import '../widgets/upgrade_page_shell.dart';
import '../providers/settings_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  User? get _user => FirebaseAuth.instance.currentUser;

  static const String _subtitle =
      'Manage your account, devices and AI preferences';

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final user = _user;
    final name = user?.displayName ?? 'Student';
    final email = user?.email ?? 'Not set';

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderCard(context, name, email),
        const SizedBox(height: 16),
        _buildSettingsCard(context, settings),
        const SizedBox(height: 16),
        _buildAIPreferencesCard(settings),
        const SizedBox(height: 16),
        _buildDevicesCard(context),
        const SizedBox(height: 24),
        _buildLogoutButton(context),
      ],
    );

    return DashboardSecondaryShell(
      highlightRoute: AppConstants.routeProfile,
      narrow: UpGradePageShell(
        title: 'Profile',
        subtitle: _subtitle,
        child: content,
      ),
      wideBody: Material(
        color: theme.colorScheme.surface,
        elevation: 1,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Profile',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.72),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              content,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, String name, String email) {
    return GradientCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppTheme.primaryBlue.withOpacity(0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.darkText.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Focused learning with UpGrade',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.darkText.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pushNamed(AppConstants.routeEditProfile);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
      BuildContext context, SettingsProvider settings) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: settings.themeMode == ThemeMode.dark,
              onChanged: (value) => settings.toggleTheme(value),
              title: const Text('Dark mode'),
              secondary: const Icon(Icons.dark_mode_outlined),
            ),
            SwitchListTile(
              value: settings.notificationsEnabled,
              onChanged: (value) =>
                  settings.setNotificationsEnabled(value),
              title: const Text('Notifications'),
              secondary: const Icon(Icons.notifications_outlined),
            ),
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Availability for group matching'),
              subtitle: Text(
                '${settings.availableStart} - ${settings.availableEnd}',
              ),
              onTap: () => _editAvailability(context, settings),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Privacy'),
              subtitle: const Text('Manage data & permissions'),
              onTap: () {
                Navigator.of(context)
                    .pushNamed(AppConstants.routePrivacySettings);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIPreferencesCard(SettingsProvider settings) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Personalization',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Preferred study style',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _ChipOption(
                  label: 'Visual',
                  selected: settings.studyStyle == StudyStyle.visual,
                  onSelected: () =>
                      settings.setStudyStyle(StudyStyle.visual),
                ),
                _ChipOption(
                  label: 'Reading',
                  selected: settings.studyStyle == StudyStyle.reading,
                  onSelected: () =>
                      settings.setStudyStyle(StudyStyle.reading),
                ),
                _ChipOption(
                  label: 'Practice',
                  selected: settings.studyStyle == StudyStyle.practice,
                  onSelected: () =>
                      settings.setStudyStyle(StudyStyle.practice),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Difficulty level',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _ChipOption(
                  label: 'Easy',
                  selected:
                      settings.difficulty == DifficultyLevel.easy,
                  onSelected: () =>
                      settings.setDifficulty(DifficultyLevel.easy),
                ),
                _ChipOption(
                  label: 'Balanced',
                  selected:
                      settings.difficulty == DifficultyLevel.balanced,
                  onSelected: () =>
                      settings.setDifficulty(DifficultyLevel.balanced),
                ),
                _ChipOption(
                  label: 'Challenging',
                  selected:
                      settings.difficulty ==
                          DifficultyLevel.challenging,
                  onSelected: () => settings
                      .setDifficulty(DifficultyLevel.challenging),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: settings.aiSuggestionsEnabled,
              onChanged: (value) =>
                  settings.setAiSuggestionsEnabled(value),
              title: const Text('AI suggestions'),
              subtitle:
                  const Text('Let UpGrade proactively suggest what to study'),
              secondary: const Icon(Icons.auto_awesome_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAvailability(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final startInitial = _parseTime(settings.availableStart) ??
        const TimeOfDay(hour: 18, minute: 0);
    final endInitial = _parseTime(settings.availableEnd) ??
        const TimeOfDay(hour: 21, minute: 0);
    final start = await showTimePicker(
      context: context,
      initialTime: startInitial,
    );
    if (start == null || !context.mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: endInitial,
    );
    if (end == null) return;
    await settings.setAvailability(
      startHHmm: _formatTime(start),
      endHHmm: _formatTime(end),
    );
  }

  TimeOfDay? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTime(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Widget _buildDevicesCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Devices',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.laptop_mac),
              title: const Text('Desktop - Chrome'),
              subtitle: const Text('Connected'),
              trailing: TextButton(
                onPressed: () {},
                child: const Text('Disconnect'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context)
                      .pushNamed(AppConstants.routeDevicePairing);
                },
                icon: const Icon(Icons.add_link),
                label: const Text('Pair new device'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppConstants.routeLogin,
              (route) => false,
            );
          }
        },
        icon: const Icon(Icons.logout),
        label: const Text('Log out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.errorRed,
          side: const BorderSide(color: AppTheme.errorRed),
        ),
      ),
    );
  }
}

class _ChipOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _ChipOption({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      label: Text(label),
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

