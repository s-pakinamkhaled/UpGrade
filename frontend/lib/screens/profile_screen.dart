import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/constants.dart';
import '../core/profile_display_name.dart';
import '../providers/settings_provider.dart';
import '../providers/classroom_provider.dart';
import '../services/api_service.dart';
import '../core/profile_completion.dart';
import '../models/task.dart';
import '../services/device_pairing_storage_service.dart';
import '../widgets/dashboard_secondary_shell.dart';
import '../widgets/upgrade_visual_system.dart';

/// Single [rem] drives all profile typography so sizes stay proportional (StudyAI-style).
class _ProfileTypeScale {
  _ProfileTypeScale(double layoutWidth)
      : rem = (layoutWidth / 92).clamp(13.0, 17.5);

  final double rem;

  double space(double mult) => rem * mult;

  double get pageTitle => rem * 1.95;
  double get pageSubtitle => rem * 0.92;
  double get cardName => rem * 1.38;
  double get email => rem * 0.88;
  double get tag => rem * 0.74;
  double get editLabel => rem * 0.88;
  double get editIcon => rem * 1.05;
  double get sectionTitle => rem * 1.18;
  double get settingTitle => rem * 0.92;
  double get settingAction => rem * 0.68;
  double get chip => rem * 0.68;
  double get avatar => rem * 3.35;
}

class ProfileScreen extends StatefulWidget {
  final bool embeddedInShell;

  const ProfileScreen({super.key, this.embeddedInShell = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoadingProfile = true;
  bool _isLoadingDeviceStatus = true;
  bool _devicePaired = false;
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
    _loadDevicePairingStatus();
  }

  Future<void> _loadDevicePairingStatus() async {
    final uid = _user?.uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _devicePaired = false;
        _isLoadingDeviceStatus = false;
      });
      return;
    }
    final paired = await DevicePairingStorageService.isPaired(uid);
    if (!mounted) return;
    setState(() {
      _devicePaired = paired;
      _isLoadingDeviceStatus = false;
    });
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final classroom = context.watch<ClassroomProvider>();
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
    final major = (_profile?['major'] as String?)?.trim() ?? '';
    final academicYear = (_profile?['academicYear'] as String?)?.trim() ?? '';
    final gpa = (_profile?['gpa'] as String?)?.trim() ?? '';
    final studentId = (_profile?['studentId'] as String?)?.trim() ?? '';
    final profileFullName = (_profile?['fullName'] as String?)?.trim() ?? '';
    final completion = calculateProfileCompletion(
      profileFullName: profileFullName,
      profileStudentId: studentId,
      profileEmail: profileEmail,
      firebaseEmail: userEmail,
      major: major,
      academicYear: academicYear,
      gpa: gpa,
    );
    final initials = name
        .split(' ')
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p.trim().substring(0, 1).toUpperCase())
        .take(2)
        .join();

    final page = _buildPageContent(
      context,
      name: name,
      email: email,
      major: major,
      academicYear: academicYear,
      gpa: gpa,
      settings: settings,
      isLoadingProfile: _isLoadingProfile,
      completion: completion,
      classroom: classroom,
      devicePaired: _devicePaired,
      isLoadingDeviceStatus: _isLoadingDeviceStatus,
      initials: initials.isNotEmpty
          ? initials
          : (name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?'),
    );

    if (widget.embeddedInShell) {
      return page;
    }

    return DashboardSecondaryShell(
      narrow: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.maybePop(context),
            tooltip: 'Back',
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: page,
      ),
      wideBody: page,
    );
  }

  Widget _buildPageContent(
    BuildContext context, {
    required String name,
    required String email,
    required String major,
    required String academicYear,
    required String gpa,
    required SettingsProvider settings,
    required bool isLoadingProfile,
    required ProfileCompletionResult completion,
    required ClassroomProvider classroom,
    required bool devicePaired,
    required bool isLoadingDeviceStatus,
    required String initials,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final t = _ProfileTypeScale(width);
        final pageRem = UpGradeRem(width);
        final side = t.space(1.15);

        return Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(side, side, side, side),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UpGradeGradientTitle(
                  'Profile',
                  rem: pageRem,
                  isDark: isDark,
                ),
                SizedBox(height: t.space(0.35)),
                UpGradeMutedSubtitle(
                  'Manage your account and preferences',
                  rem: pageRem,
                  isDark: isDark,
                ),
                SizedBox(height: t.space(1.0)),
                _buildHeaderCard(
                  context,
                  name: name,
                  email: email,
                  initials: initials,
                  major: major,
                  academicYear: academicYear,
                  gpa: gpa,
                  isDark: isDark,
                  t: t,
                  layoutWidth: width,
                ),
                if (isLoadingProfile) ...[
                  SizedBox(height: t.space(0.65)),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                SizedBox(height: t.space(1.0)),
                _buildProfileCompletionCard(
                  completion: completion,
                  t: t,
                  isDark: isDark,
                ),
                SizedBox(height: t.space(0.65)),
                _buildStudyPreferencesCard(
                  context,
                  settings: settings,
                  t: t,
                  isDark: isDark,
                ),
                SizedBox(height: t.space(0.65)),
                _buildConnectedServicesCard(
                  context,
                  googleClassroomConnected: classroom.googleClassroomConnected,
                  devicePaired: devicePaired,
                  isLoadingDeviceStatus: isLoadingDeviceStatus,
                  t: t,
                  isDark: isDark,
                ),
                SizedBox(height: t.space(0.65)),
                _buildTaskSummaryCard(
                  tasks: classroom.tasks,
                  t: t,
                  isDark: isDark,
                  layoutWidth: width,
                ),
                SizedBox(height: t.space(0.55)),
                _buildSignOutCard(context, t, isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(
    BuildContext context, {
    required String name,
    required String email,
    required String initials,
    required String major,
    required String academicYear,
    required String gpa,
    required bool isDark,
    required _ProfileTypeScale t,
    required double layoutWidth,
  }) {
    final useRow = layoutWidth >= 560;
    final avatarSize = t.avatar.clamp(52.0, 88.0);

    final infoColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: t.cardName,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
            height: 1.15,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        SizedBox(height: t.space(0.55)),
        if (major.isNotEmpty || academicYear.isNotEmpty || gpa.isNotEmpty)
          Wrap(
            spacing: t.space(0.45),
            runSpacing: t.space(0.45),
            children: [
              if (major.isNotEmpty)
                _Tag(
                  icon: Icons.school_outlined,
                  label: major,
                  bg: const Color(0xFFE6EFFC),
                  fg: const Color(0xFF315B9A),
                  fontSize: t.tag,
                ),
              if (academicYear.isNotEmpty)
                _Tag(
                  label: academicYear,
                  bg: const Color(0xFFF3F4F6),
                  fg: const Color(0xFF334155),
                  fontSize: t.tag,
                ),
              if (gpa.isNotEmpty)
                _Tag(
                  label: 'GPA: $gpa',
                  bg: const Color(0xFFDCFCE7),
                  fg: const Color(0xFF15803D),
                  fontSize: t.tag,
                ),
            ],
          )
        else
          Text(
            'No profile details yet. Use Edit Profile to add major, year, or GPA.',
            style: TextStyle(
              fontSize: t.email,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
            ),
          ),
        SizedBox(height: t.space(0.55)),
        Row(
          children: [
            Icon(
              Icons.mail_outline,
              size: t.email * 1.05,
              color: const Color(0xFF64748B),
            ),
            SizedBox(width: t.space(0.45)),
            Expanded(
              child: Text(
                email,
                style: TextStyle(
                  fontSize: t.email,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    final editButton = DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.softShadow,
      ),
      child: ElevatedButton.icon(
        onPressed: _openEditProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: t.space(1.1),
            vertical: t.space(0.75),
          ),
        ),
        icon: Icon(Icons.edit_outlined, size: t.editIcon),
        label: Text(
          'Edit Profile',
          style: TextStyle(
            fontSize: t.editLabel,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    final avatar = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        shape: BoxShape.circle,
        boxShadow: AppTheme.softShadow,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: (avatarSize * 0.36).clamp(18.0, 34.0),
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(t.space(1.45)),
      decoration: BoxDecoration(
        gradient: isDark
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFF7F2FC),
                ],
              ),
        color: isDark ? const Color(0xFF111827) : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE8E0EF),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(isDark ? 0.18 : 0.1),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppTheme.secondaryPurple.withOpacity(isDark ? 0.12 : 0.06),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: useRow
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                avatar,
                SizedBox(width: t.space(1.15)),
                Expanded(child: infoColumn),
                SizedBox(width: t.space(0.75)),
                editButton,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    avatar,
                    SizedBox(width: t.space(1.0)),
                    Expanded(child: infoColumn),
                  ],
                ),
                SizedBox(height: t.space(1.0)),
                SizedBox(width: double.infinity, child: editButton),
              ],
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required _ProfileTypeScale t,
    required bool isDark,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(t.space(1.15)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE8E0EF),
        ),
        boxShadow: [
          BoxShadow(
            color: iconFg.withOpacity(isDark ? 0.1 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(t.space(0.45)),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: iconFg.withOpacity(0.2)),
                ),
                child: Icon(icon, color: iconFg, size: t.settingTitle * 1.15),
              ),
              SizedBox(width: t.space(0.65)),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: t.sectionTitle * 0.92,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          SizedBox(height: t.space(0.75)),
          child,
        ],
      ),
    );
  }

  Widget _buildProfileCompletionCard({
    required ProfileCompletionResult completion,
    required _ProfileTypeScale t,
    required bool isDark,
  }) {
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    return _buildSectionCard(
      title: 'Profile Completion',
      icon: Icons.task_alt_outlined,
      iconBg: const Color(0xFFDCFCE7),
      iconFg: const Color(0xFF15803D),
      t: t,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Profile ${completion.percent}% complete',
            style: TextStyle(
              fontSize: t.settingTitle,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: t.space(0.55)),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: completion.percent / 100,
              minHeight: 8,
              backgroundColor:
                  isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF15803D)),
            ),
          ),
          if (completion.missingFieldLabels.isNotEmpty) ...[
            SizedBox(height: t.space(0.65)),
            Text(
              'Still needed:',
              style: TextStyle(
                fontSize: t.email,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
            SizedBox(height: t.space(0.35)),
            Wrap(
              spacing: t.space(0.4),
              runSpacing: t.space(0.4),
              children: completion.missingFieldLabels
                  .map(
                    (label) => _statusBadge(
                      label,
                      isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
                      muted,
                      t.chip,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudyPreferencesCard(
    BuildContext context, {
    required SettingsProvider settings,
    required _ProfileTypeScale t,
    required bool isDark,
  }) {
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    return _buildSectionCard(
      title: 'Study Preferences',
      icon: Icons.schedule_outlined,
      iconBg: const Color(0xFFEDE9FE),
      iconFg: AppTheme.secondaryPurple,
      t: t,
      isDark: isDark,
      trailing: TextButton(
        onPressed: () => _openStudyPreferencesEditor(context, settings, t, isDark),
        child: Text(
          'Edit',
          style: TextStyle(
            fontSize: t.settingAction,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondaryPurple,
          ),
        ),
      ),
      child: Column(
        children: [
          _preferenceRow(
            'Preferred study time',
            settings.preferredStudyTime,
            t,
            muted,
            isDark,
          ),
          SizedBox(height: t.space(0.45)),
          _preferenceRow(
            'Daily study goal',
            settings.dailyStudyGoal,
            t,
            muted,
            isDark,
          ),
          SizedBox(height: t.space(0.45)),
          _preferenceRow(
            'Reminder time',
            settings.reminderTime,
            t,
            muted,
            isDark,
          ),
          SizedBox(height: t.space(0.45)),
          _preferenceRow(
            'Focus session duration',
            settings.focusSessionDuration,
            t,
            muted,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _preferenceRow(
    String label,
    String? value,
    _ProfileTypeScale t,
    Color muted,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: t.email,
              fontWeight: FontWeight.w500,
              color: muted,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            (value != null && value.isNotEmpty) ? value : 'Not set yet',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: t.settingTitle,
              fontWeight: FontWeight.w600,
              color: (value != null && value.isNotEmpty)
                  ? (isDark ? Colors.white : const Color(0xFF1E293B))
                  : muted,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openStudyPreferencesEditor(
    BuildContext context,
    SettingsProvider settings,
    _ProfileTypeScale t,
    bool isDark,
  ) async {
    final preferredCtrl = TextEditingController(
      text: settings.preferredStudyTime ?? '',
    );
    final goalCtrl = TextEditingController(text: settings.dailyStudyGoal ?? '');
    final reminderCtrl = TextEditingController(text: settings.reminderTime ?? '');
    final focusCtrl = TextEditingController(
      text: settings.focusSessionDuration ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Study preferences'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: preferredCtrl,
                decoration: const InputDecoration(
                  labelText: 'Preferred study time',
                  hintText: 'e.g. 6:00 PM – 9:00 PM',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: goalCtrl,
                decoration: const InputDecoration(
                  labelText: 'Daily study goal',
                  hintText: 'e.g. 2 hours',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reminderCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reminder time',
                  hintText: 'e.g. 8:00 AM',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: focusCtrl,
                decoration: const InputDecoration(
                  labelText: 'Focus session duration',
                  hintText: 'e.g. 45 minutes',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true && context.mounted) {
      await settings.setStudyPreferences(
        preferredStudyTime: preferredCtrl.text,
        dailyStudyGoal: goalCtrl.text,
        reminderTime: reminderCtrl.text,
        focusSessionDuration: focusCtrl.text,
      );
    }

    preferredCtrl.dispose();
    goalCtrl.dispose();
    reminderCtrl.dispose();
    focusCtrl.dispose();
  }

  Widget _buildConnectedServicesCard(
    BuildContext context, {
    required bool googleClassroomConnected,
    required bool devicePaired,
    required bool isLoadingDeviceStatus,
    required _ProfileTypeScale t,
    required bool isDark,
  }) {
    final classroomStatus = googleClassroomConnected
        ? 'Connected'
        : 'Not connected';
    final pairingStatus = isLoadingDeviceStatus
        ? 'Checking…'
        : (devicePaired ? 'Paired' : 'Not paired');

    return _buildSectionCard(
      title: 'Connected Services',
      icon: Icons.hub_outlined,
      iconBg: const Color(0xFFDBEAFE),
      iconFg: AppTheme.primaryBlue,
      t: t,
      isDark: isDark,
      child: Column(
        children: [
          _serviceStatusRow(
            icon: Icons.school_outlined,
            label: 'Google Classroom',
            status: classroomStatus,
            isPositive: googleClassroomConnected,
            t: t,
            isDark: isDark,
            onTap: () => Navigator.of(context)
                .pushNamed(AppConstants.routeGoogleClassroomSync),
          ),
          SizedBox(height: t.space(0.45)),
          _serviceStatusRow(
            icon: Icons.phonelink_setup_outlined,
            label: 'Device Pairing',
            status: pairingStatus,
            isPositive: devicePaired,
            t: t,
            isDark: isDark,
            onTap: () async {
              await Navigator.of(context)
                  .pushNamed(AppConstants.devicePairingEntryRouteFor(context));
              if (!mounted) return;
              await _loadDevicePairingStatus();
            },
          ),
        ],
      ),
    );
  }

  Widget _serviceStatusRow({
    required IconData icon,
    required String label,
    required String status,
    required bool isPositive,
    required _ProfileTypeScale t,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    final statusColor = isPositive
        ? const Color(0xFF15803D)
        : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B));
    final row = Row(
      children: [
        Icon(icon, size: t.settingTitle * 1.1, color: AppTheme.primaryBlue),
        SizedBox(width: t.space(0.55)),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: t.settingTitle,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ),
        Text(
          status,
          style: TextStyle(
            fontSize: t.settingAction,
            fontWeight: FontWeight.w700,
            color: statusColor,
          ),
        ),
        if (onTap != null) ...[
          SizedBox(width: t.space(0.25)),
          Icon(
            Icons.chevron_right,
            size: t.settingTitle,
            color: statusColor.withOpacity(0.75),
          ),
        ],
      ],
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: t.space(0.25)),
          child: row,
        ),
      ),
    );
  }

  Widget _buildTaskSummaryCard({
    required List<Task> tasks,
    required _ProfileTypeScale t,
    required bool isDark,
    required double layoutWidth,
  }) {
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

    if (tasks.isEmpty) {
      return _buildSectionCard(
        title: 'Task Summary',
        icon: Icons.checklist_rtl_outlined,
        iconBg: const Color(0xFFFFEDD5),
        iconFg: const Color(0xFF9A3412),
        t: t,
        isDark: isDark,
        child: Text(
          'No tasks available yet',
          style: TextStyle(
            fontSize: t.settingTitle,
            fontWeight: FontWeight.w500,
            color: muted,
          ),
        ),
      );
    }

    final total = tasks.length;
    final completed =
        tasks.where((task) => task.status == TaskStatus.completed).length;
    final pending = tasks
        .where(
          (task) =>
              task.status == TaskStatus.pending ||
              task.status == TaskStatus.inProgress,
        )
        .length;
    final missed =
        tasks.where((task) => task.status == TaskStatus.missed).length;

    final useGrid = layoutWidth >= 520;
    final stats = [
      _TaskStat('Total', total, const Color(0xFFDBEAFE), AppTheme.primaryBlue),
      _TaskStat('Completed', completed, const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      _TaskStat('Pending', pending, const Color(0xFFFFEDD5), const Color(0xFF9A3412)),
      _TaskStat('Missed', missed, const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
    ];

    return _buildSectionCard(
      title: 'Task Summary',
      icon: Icons.checklist_rtl_outlined,
      iconBg: const Color(0xFFFFEDD5),
      iconFg: const Color(0xFF9A3412),
      t: t,
      isDark: isDark,
      child: useGrid
          ? Wrap(
              spacing: t.space(0.55),
              runSpacing: t.space(0.55),
              children: stats
                  .map((s) => _taskStatTile(s, t, isDark, layoutWidth))
                  .toList(),
            )
          : Column(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) SizedBox(height: t.space(0.45)),
                  _taskStatTile(stats[i], t, isDark, layoutWidth),
                ],
              ],
            ),
    );
  }

  Widget _taskStatTile(
    _TaskStat stat,
    _ProfileTypeScale t,
    bool isDark,
    double layoutWidth,
  ) {
    final tileWidth = layoutWidth >= 520
        ? ((layoutWidth - t.space(2.3)) / 2).clamp(120.0, 280.0)
        : double.infinity;
    return SizedBox(
      width: tileWidth,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: t.space(0.85),
          vertical: t.space(0.65),
        ),
        decoration: BoxDecoration(
          color: stat.bg.withOpacity(isDark ? 0.25 : 1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: stat.fg.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                stat.label,
                style: TextStyle(
                  fontSize: t.email,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                ),
              ),
            ),
            Text(
              '${stat.count}',
              style: TextStyle(
                fontSize: t.sectionTitle,
                fontWeight: FontWeight.w800,
                color: stat.fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutCard(
    BuildContext context,
    _ProfileTypeScale t,
    bool isDark,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Sign out'),
              content: const Text('Are you sure you want to sign out?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          );
          if (ok != true || !context.mounted) return;
          await context.read<ClassroomProvider>().clearUserData();
          await FirebaseAuth.instance.signOut();
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppConstants.routeLogin,
              (route) => false,
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color(0xFFEF4444).withOpacity(0.15),
        highlightColor: const Color(0xFFEF4444).withOpacity(0.08),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: t.space(1.15),
            vertical: t.space(0.95),
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A1418) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: const Color(0xFFB91C1C),
                size: t.settingTitle * 1.15,
              ),
              SizedBox(width: t.space(0.65)),
              Expanded(
                child: Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: t.settingTitle,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB91C1C),
                  ),
                ),
              ),
              Text(
                'Confirm',
                style: TextStyle(
                  fontSize: t.settingAction,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFB91C1C),
                ),
              ),
              SizedBox(width: t.space(0.25)),
              Icon(Icons.chevron_right, size: t.settingTitle * 1.05, color: const Color(0xFFB91C1C)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String label, Color bg, Color fg, double fontSize) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 1.15,
        vertical: fontSize * 0.45,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: fg.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TaskStat {
  final String label;
  final int count;
  final Color bg;
  final Color fg;

  const _TaskStat(this.label, this.count, this.bg, this.fg);
}

class _Tag extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color bg;
  final Color fg;
  final double fontSize;

  const _Tag({
    this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.85,
        vertical: fontSize * 0.38,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: fg.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize * 1.1, color: fg),
            SizedBox(width: fontSize * 0.35),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}

