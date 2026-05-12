import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/constants.dart';
import '../core/profile_display_name.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
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
  double get statValue => rem * 1.52;
  double get statLabel => rem * 0.78;
  double get sectionTitle => rem * 1.18;
  double get settingTitle => rem * 0.92;
  double get settingAction => rem * 0.68;
  double get chip => rem * 0.68;
  double get avatar => rem * 3.35;
}

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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
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
        body: _buildPage(
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
      ),
    );
  }

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
        final t = _ProfileTypeScale(width);
        final pageRem = UpGradeRem(width);
        final side = t.space(1.15);

        Widget settingsChips() {
          return Wrap(
            spacing: t.space(0.55),
            runSpacing: t.space(0.55),
            children: [
              _statusBadge(
                'Notifications ${settings.notificationsEnabled ? 'On' : 'Off'}',
                settings.notificationsEnabled
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFE5E7EB),
                settings.notificationsEnabled
                    ? const Color(0xFF166534)
                    : const Color(0xFF334155),
                t.chip,
              ),
              _statusBadge(
                'Focus Tracking ${settings.aiSuggestionsEnabled ? 'On' : 'Off'}',
                settings.aiSuggestionsEnabled
                    ? const Color(0xFFEDE9FE)
                    : const Color(0xFFE5E7EB),
                settings.aiSuggestionsEnabled
                    ? const Color(0xFF6D28D9)
                    : const Color(0xFF334155),
                t.chip,
              ),
              _statusBadge(
                'Data Sharing ${settings.dataSharingEnabled ? 'On' : 'Off'}',
                settings.dataSharingEnabled
                    ? const Color(0xFFDBEAFE)
                    : const Color(0xFFE5E7EB),
                settings.dataSharingEnabled
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF334155),
                t.chip,
              ),
              _statusBadge(
                '2FA ${settings.twoFactorEnabled ? 'On' : 'Off'}',
                settings.twoFactorEnabled
                    ? const Color(0xFFFFEDD5)
                    : const Color(0xFFE5E7EB),
                settings.twoFactorEnabled
                    ? const Color(0xFF9A3412)
                    : const Color(0xFF334155),
                t.chip,
              ),
            ],
          );
        }

        return Container(
          decoration: UpGradePageDecor.pageBackground(isDark),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(side),
            child: Column(
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
                SizedBox(height: t.space(1.35)),
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
                SizedBox(height: t.space(1.25)),
                _buildStatsRow(
                  t: t,
                  contentWidth: width,
                  isDark: isDark,
                ),
                SizedBox(height: t.space(1.35)),
                Row(
                  children: [
                    Container(
                      width: t.space(0.22).clamp(3.0, 5.0),
                      height: t.sectionTitle * 1.15,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: AppTheme.softShadow,
                      ),
                    ),
                    SizedBox(width: t.space(0.5)),
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: t.sectionTitle,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: t.space(0.65)),
                settingsChips(),
                SizedBox(height: t.space(0.65)),
                _buildPrivacyDeviceRows(context, t, isDark),
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
        Wrap(
          spacing: t.space(0.45),
          runSpacing: t.space(0.45),
          children: [
            _Tag(
              icon: Icons.school_outlined,
              label: major,
              bg: const Color(0xFFE6EFFC),
              fg: const Color(0xFF315B9A),
              fontSize: t.tag,
            ),
            _Tag(
              label: academicYear,
              bg: const Color(0xFFF3F4F6),
              fg: const Color(0xFF334155),
              fontSize: t.tag,
            ),
            _Tag(
              label: 'GPA: $gpa',
              bg: const Color(0xFFDCFCE7),
              fg: const Color(0xFF15803D),
              fontSize: t.tag,
            ),
          ],
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
  Widget _buildStatsRow({
    required _ProfileTypeScale t,
    required double contentWidth,
    required bool isDark,
  }) {
    final stats = <(String, String, Color, Color, Color)>[
      ('247h', 'Study Hours', const Color(0xFF2563EB), const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
      ('156', 'Tasks Completed', const Color(0xFF7C3AED), const Color(0xFFF5F3FF), const Color(0xFF6D28D9)),
      ('12 days', 'Current Streak', const Color(0xFF059669), const Color(0xFFECFDF5), const Color(0xFF047857)),
      ('87%', 'Avg Focus Score', const Color(0xFFD97706), const Color(0xFFFFFBEB), const Color(0xFFB45309)),
    ];

    final gap = t.space(0.75);
    int cols = 1;
    if (contentWidth >= 960) {
      cols = 4;
    } else if (contentWidth >= 520) {
      cols = 2;
    }
    final itemW = cols > 1
        ? ((contentWidth - gap * (cols - 1)) / cols).clamp(140.0, 420.0)
        : contentWidth;

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: List.generate(stats.length, (i) {
        final item = stats[i];
        final accent = item.$3;
        final soft = item.$4;
        final valueFg = item.$5;

        return SizedBox(
          width: itemW,
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: t.space(1.35),
              horizontal: t.space(0.65),
            ),
            decoration: BoxDecoration(
              gradient: isDark
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1E293B),
                        accent.withOpacity(0.12),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        soft,
                        Colors.white,
                      ],
                    ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: accent.withOpacity(isDark ? 0.45 : 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(isDark ? 0.2 : 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  item.$1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: t.statValue,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.05,
                    color: isDark ? Colors.white : valueFg,
                  ),
                ),
                SizedBox(height: t.space(0.35)),
                Text(
                  item.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: t.statLabel,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: isDark ? const Color(0xFF9CA3AF) : accent.withOpacity(0.88),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPrivacyDeviceRows(
    BuildContext context,
    _ProfileTypeScale t,
    bool isDark,
  ) {
    return Column(
      children: [
        _settingRow(
          icon: Icons.settings_outlined,
          title: 'Privacy Settings',
          action: 'Configure',
          iconBg: const Color(0xFFDBEAFE),
          iconFg: AppTheme.primaryBlue,
          splash: AppTheme.primaryBlue,
          t: t,
          isDark: isDark,
          onTap: () =>
              Navigator.of(context).pushNamed(AppConstants.routePrivacySettings),
        ),
        SizedBox(height: t.space(0.5)),
        _settingRow(
          icon: Icons.phonelink_setup_outlined,
          title: 'Device Pairing',
          action: 'Manage',
          iconBg: const Color(0xFFEDE9FE),
          iconFg: AppTheme.secondaryPurple,
          splash: AppTheme.secondaryPurple,
          t: t,
          isDark: isDark,
          onTap: () =>
              Navigator.of(context).pushNamed(AppConstants.routeDevicePairing),
        ),
      ],
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

  Widget _settingRow({
    required IconData icon,
    required String title,
    required String action,
    required Color iconBg,
    required Color iconFg,
    required Color splash,
    required _ProfileTypeScale t,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: splash.withOpacity(0.14),
        highlightColor: splash.withOpacity(0.07),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: t.space(1.15),
            vertical: t.space(0.95),
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF334155)
                  : splash.withOpacity(0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: splash.withOpacity(isDark ? 0.12 : 0.08),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(t.space(0.45)),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: iconFg.withOpacity(0.2)),
                ),
                child: Icon(
                  icon,
                  color: iconFg,
                  size: t.settingTitle * 1.15,
                ),
              ),
              SizedBox(width: t.space(0.65)),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: t.settingTitle,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              Text(
                action,
                style: TextStyle(
                  fontSize: t.settingAction,
                  fontWeight: FontWeight.w800,
                  color: splash,
                ),
              ),
              SizedBox(width: t.space(0.25)),
              Icon(Icons.chevron_right, size: t.settingTitle * 1.1, color: splash.withOpacity(0.75)),
            ],
          ),
        ),
      ),
    );
  }
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

