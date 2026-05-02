import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/constants.dart';
<<<<<<< HEAD
import '../widgets/dashboard_secondary_shell.dart';
import '../widgets/gradient_card.dart';
import '../widgets/upgrade_page_shell.dart';
import '../providers/settings_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  User? get _user => FirebaseAuth.instance.currentUser;

  static const String _subtitle =
      'Manage your account, devices and AI preferences';
=======
import '../core/profile_display_name.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../widgets/dashboard_secondary_shell.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoadingProfile = true;
  Map<String, dynamic>? _profile;

  User? get _user => FirebaseAuth.instance.currentUser;
  String get _userId {
    final user = _user;
    return user?.uid ?? user?.email ?? 'guest_user';
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ApiService().getUserProfile(_userId);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _isLoadingProfile = false;
    });
  }

  Future<void> _openEditProfile() async {
    await Navigator.of(context).pushNamed(AppConstants.routeEditProfile);
    if (!mounted) return;
    await _loadProfile();
  }
>>>>>>> origin/continue

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
<<<<<<< HEAD
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
=======
    final user = _user;
    final userEmail = user?.email?.trim() ?? '';
    final profileEmail = (_profile?['email'] as String?)?.trim() ?? '';
    final email = (!isPlaceholderProfileEmail(profileEmail) && profileEmail.isNotEmpty)
        ? profileEmail
        : (userEmail.isNotEmpty ? userEmail : profileEmail);

    final profileName = (_profile?['fullName'] as String?)?.trim() ?? '';
    final firebaseName = user?.displayName?.trim() ?? '';
    // Prefer real profile / Firebase name; ignore seed placeholders like "John Doe"
    // so the UI falls back to the local part of the email (e.g. pakinam@… → "Pakinam").
    final name = (profileName.isNotEmpty && !isPlaceholderProfileName(profileName))
        ? profileName
        : (firebaseName.isNotEmpty && !isPlaceholderProfileName(firebaseName))
            ? firebaseName
            : displayNameFromEmail(
                email.isNotEmpty ? email : userEmail,
              );
    final major = ((_profile?['major'] as String?)?.trim().isNotEmpty ?? false)
        ? (_profile!['major'] as String).trim()
        : 'Computer Science';
    final academicYear =
        ((_profile?['academicYear'] as String?)?.trim().isNotEmpty ?? false)
            ? (_profile!['academicYear'] as String).trim()
            : 'Junior';
    final gpa = ((_profile?['gpa'] as String?)?.trim().isNotEmpty ?? false)
        ? (_profile!['gpa'] as String).trim()
        : '3.85';
    final initials = name
        .split(' ')
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p.trim().substring(0, 1).toUpperCase())
        .take(2)
        .join();

    return DashboardSecondaryShell(
      highlightRoute: AppConstants.routeProfile,
      narrow: _buildPage(
        context,
        name: name,
        email: email,
        major: major,
        academicYear: academicYear,
        gpa: gpa,
        settings: settings,
        isLoadingProfile: _isLoadingProfile,
        initials: initials.isNotEmpty
            ? initials
            : (name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?'),
      ),
      wideBody: _buildPage(
        context,
        name: name,
        email: email,
        major: major,
        academicYear: academicYear,
        gpa: gpa,
        settings: settings,
        isLoadingProfile: _isLoadingProfile,
        initials: initials.isNotEmpty
            ? initials
            : (name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?'),
>>>>>>> origin/continue
      ),
    );
  }

<<<<<<< HEAD
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
=======
  Widget _buildPage(
    BuildContext context, {
    required String name,
    required String email,
    required String major,
    required String academicYear,
    required String gpa,
    required SettingsProvider settings,
    required bool isLoadingProfile,
    required String initials,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final s = (width / 1440).clamp(0.62, 1.0);
        final side = 16.0 + (12.0 * s);

        return Container(
          color: isDark ? const Color(0xFF0B1220) : const Color(0xFFF1F5F9),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(side),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 44 * s,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 4 * s),
                Text(
                  'Manage your account and preferences',
                  style: TextStyle(
                    fontSize: 24 * s,
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : AppTheme.darkText.withOpacity(0.7),
                  ),
                ),
                SizedBox(height: 22 * s),
                _buildHeaderCard(
                  context,
                  name,
                  email,
                  initials,
                  s,
                  major,
                  academicYear,
                  gpa,
                  isDark,
                ),
                if (isLoadingProfile) ...[
                  SizedBox(height: 10 * s),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                SizedBox(height: 18 * s),
                _buildStatsRow(s),
                SizedBox(height: 18 * s),
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 34 * s,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 10 * s),
                Wrap(
                  spacing: 8 * s,
                  runSpacing: 8 * s,
                  children: [
                    _statusBadge(
                      'Notifications ${settings.notificationsEnabled ? 'On' : 'Off'}',
                      settings.notificationsEnabled ? const Color(0xFFDCFCE7) : const Color(0xFFE5E7EB),
                      settings.notificationsEnabled ? const Color(0xFF166534) : const Color(0xFF334155),
                      s,
                    ),
                    _statusBadge(
                      'Focus Tracking ${settings.aiSuggestionsEnabled ? 'On' : 'Off'}',
                      settings.aiSuggestionsEnabled ? const Color(0xFFEDE9FE) : const Color(0xFFE5E7EB),
                      settings.aiSuggestionsEnabled ? const Color(0xFF6D28D9) : const Color(0xFF334155),
                      s,
                    ),
                    _statusBadge(
                      'Data Sharing ${settings.dataSharingEnabled ? 'On' : 'Off'}',
                      settings.dataSharingEnabled ? const Color(0xFFDBEAFE) : const Color(0xFFE5E7EB),
                      settings.dataSharingEnabled ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                      s,
                    ),
                    _statusBadge(
                      '2FA ${settings.twoFactorEnabled ? 'On' : 'Off'}',
                      settings.twoFactorEnabled ? const Color(0xFFFFEDD5) : const Color(0xFFE5E7EB),
                      settings.twoFactorEnabled ? const Color(0xFF9A3412) : const Color(0xFF334155),
                      s,
                    ),
                  ],
                ),
                SizedBox(height: 10 * s),
                _buildSettingsList(context, s, isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    String name,
    String email,
    String initials,
    double s,
    String major,
    String academicYear,
    String gpa,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24 * s),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF7F2FB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE6DEEF),
        ),
      ),
      child: Wrap(
        spacing: 16 * s,
        runSpacing: 16 * s,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: 96 * s,
            height: 96 * s,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: s < 0.82 ? double.infinity : null,
>>>>>>> origin/continue
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
<<<<<<< HEAD
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
=======
                  style: TextStyle(
                    fontSize: 44 * s,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 10 * s),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Tag(
                      icon: Icons.school_outlined,
                      label: major,
                      bg: Color(0xFFE6EFFC),
                      fg: Color(0xFF315B9A),
                      scale: s,
                    ),
                    _Tag(
                      label: academicYear,
                      bg: Color(0xFFF3F4F6),
                      fg: Color(0xFF334155),
                      scale: s,
                    ),
                    _Tag(
                      label: 'GPA: $gpa',
                      bg: Color(0xFFDCFCE7),
                      fg: Color(0xFF15803D),
                      scale: s,
                    ),
                  ],
                ),
                SizedBox(height: 10 * s),
                Row(
                  children: [
                    Icon(Icons.mail_outline, size: 18 * s, color: const Color(0xFF64748B)),
                    SizedBox(width: 8 * s),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 24 * s,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF475569),
                      ),
                    ),
                  ],
>>>>>>> origin/continue
                ),
              ],
            ),
          ),
<<<<<<< HEAD
          TextButton(
            onPressed: () {
              Navigator.of(context).pushNamed(AppConstants.routeEditProfile);
            },
            child: const Text('Edit'),
=======
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton.icon(
              onPressed: _openEditProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                foregroundColor: Colors.white,
                padding:
                    EdgeInsets.symmetric(horizontal: 18 * s, vertical: 14 * s),
              ),
              icon: Icon(Icons.edit_outlined, size: 18 * s),
              label: Text(
                'Edit Profile',
                style: TextStyle(fontSize: 20 * s, fontWeight: FontWeight.w600),
              ),
            ),
>>>>>>> origin/continue
          ),
        ],
      ),
    );
  }

<<<<<<< HEAD
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
=======
  Widget _buildStatsRow(double s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const stats = [
      ('247h', 'Study Hours'),
      ('156', 'Tasks Completed'),
      ('12 days', 'Current Streak'),
      ('87%', 'Avg Focus Score'),
    ];

    return Wrap(
      spacing: 12 * s,
      runSpacing: 12 * s,
      children: stats.map((item) {
        return SizedBox(
          width: 240 * s,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 24 * s),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                Text(
                  item.$1,
                  style: TextStyle(
                    fontSize: 44 * s,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 6 * s),
                Text(
                  item.$2,
                  style: TextStyle(
                    fontSize: 22 * s,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSettingsList(BuildContext context, double s, bool isDark) {
    return Column(
      children: [
        _settingRow(
          icon: Icons.settings_outlined,
          title: 'Privacy Settings',
          action: 'Configure',
          scale: s,
          isDark: isDark,
          onTap: () => Navigator.of(context).pushNamed(AppConstants.routePrivacySettings),
        ),
        SizedBox(height: 8 * s),
        _settingRow(
          icon: Icons.person_outline,
          title: 'Device Pairing',
          action: 'Manage',
          scale: s,
          isDark: isDark,
          onTap: () => Navigator.of(context).pushNamed(AppConstants.routeDevicePairing),
        ),
        SizedBox(height: 8 * s),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 16 * s),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A1418) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.logout, color: const Color(0xFFB91C1C), size: 22 * s),
              SizedBox(width: 12 * s),
              Expanded(
                child: Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 17 * s,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppConstants.routeLogin,
                      (route) => false,
                    );
                  }
                },
                child: const Text(''),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingRow({
    required IconData icon,
    required String title,
    required String action,
    required double scale,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18 * scale, vertical: 16 * scale),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF64748B), size: 22 * scale),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 17 * scale,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 4 * scale),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    action,
                    style: TextStyle(
                      fontSize: 13 * scale,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
>>>>>>> origin/continue
            ),
          ],
        ),
      ),
    );
  }

<<<<<<< HEAD
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
=======
  Widget _statusBadge(String label, Color bg, Color fg, double s) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 6 * s),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 17 * s,
          fontWeight: FontWeight.w600,
>>>>>>> origin/continue
        ),
      ),
    );
  }
}

<<<<<<< HEAD
class _ChipOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _ChipOption({
    required this.label,
    required this.selected,
    required this.onSelected,
=======
class _Tag extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color bg;
  final Color fg;
  final double scale;

  const _Tag({
    this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    this.scale = 1.0,
>>>>>>> origin/continue
  });

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    return FilterChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      label: Text(label),
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
=======
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            SizedBox(width: 6 * scale),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 18 * scale,
            ),
          ),
        ],
>>>>>>> origin/continue
      ),
    );
  }
}

