import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/classroom_course.dart';
import '../widgets/upgrade_visual_system.dart';
import '../widgets/upgrade_page_shell.dart';
import '../services/google_auth_service.dart';
import '../services/classroom_sync_service.dart';
import '../services/classroom_storage_service.dart';
import '../services/semester_filter_service.dart';
import '../providers/classroom_provider.dart';
import '../providers/dashboard_shell_provider.dart';

/// Accent pairs for enrolled course tiles: [soft bg, strong accent].
const List<List<Color>> _enrolledCourseAccents = [
  [Color(0xFFEEF2FF), Color(0xFF4F46E5)],
  [Color(0xFFE0F2FE), Color(0xFF0284C7)],
  [Color(0xFFD1FAE5), Color(0xFF059669)],
  [Color(0xFFFEF3C7), Color(0xFFD97706)],
  [Color(0xFFFCE7F3), Color(0xFFC026D3)],
  [Color(0xFFF3E8FF), Color(0xFF7C3AED)],
];

List<Color> _accentForCourseId(String id) {
  return _enrolledCourseAccents[
      id.hashCode.abs() % _enrolledCourseAccents.length];
}

class GoogleClassroomSyncScreen extends StatefulWidget {
  /// When true (post sign-in flow), show a strip to continue to device pairing.
  final bool fromPostLoginSetup;

  const GoogleClassroomSyncScreen({
    super.key,
    this.fromPostLoginSetup = false,
  });

  @override
  State<GoogleClassroomSyncScreen> createState() =>
      _GoogleClassroomSyncScreenState();
}

class _GoogleClassroomSyncScreenState extends State<GoogleClassroomSyncScreen> {
  bool _isPreparingSemesters = false;
  String? _accessToken;
  String? _selectedSemesterId;
  List<SemesterOption> _semesterOptions = const [];
  final TextEditingController _manualCourseController = TextEditingController();

  /// After the user continues past the Classroom connect sheet (email/password app sign-in).
  bool _classroomConnectAcknowledged = false;

  static const String _pageSubtitle =
      'Connect and sync your coursework automatically.';

  @override
  void initState() {
    super.initState();
    _loadSavedSemesterId();
  }

  @override
  void dispose() {
    _manualCourseController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSemesterId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final savedId = await ClassroomStorageService.getSelectedSemesterId(uid);
    if (!mounted) return;
    setState(() {
      _selectedSemesterId = savedId;
    });
  }

  bool _firebaseUserLinkedWithGoogle() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'google.com');
  }

  Future<void> _populateSemestersFromToken(String accessToken) async {
    final courses = await ClassroomSyncService.fetchCourses(accessToken);
    final semesters = SemesterFilterService.extractSemestersOrFallback(courses);
    final selected = SemesterFilterService.selectDefaultSemesterId(
      semesters,
      savedSemesterId: _selectedSemesterId,
    );

    if (!mounted) return;
    setState(() {
      _semesterOptions = semesters;
      _selectedSemesterId = selected;
    });
  }

  /// Google Classroom only supports Google OAuth (no third-party password field).
  /// For email/password app accounts we collect the school Google email, then open Google sign-in.
  Future<bool> _showClassroomConnectDialog() async {
    final emailController = TextEditingController(
      text: FirebaseAuth.instance.currentUser?.email ?? '',
    );
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final bodySmall = Theme.of(ctx).textTheme.bodySmall;
        return AlertDialog(
          title: const Text('Connect Google Classroom'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'You signed in to ${AppConstants.appName} with email and password. '
                  'Classroom sync uses the Google account your school uses for Classroom.',
                  style: bodySmall?.copyWith(height: 1.35),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Google / Classroom email',
                    hintText: 'you@school.edu',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Google password: you will type it only on Google\'s sign-in screen '
                  'after you tap Continue with Google — not in this box.',
                  style: bodySmall?.copyWith(height: 1.35),
                ),
                const SizedBox(height: 14),
                Text(
                  'Tap Continue to open Google\'s official sign-in. '
                  'This app never stores your Google password.',
                  style: bodySmall?.copyWith(
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue with Google'),
            ),
          ],
        );
      },
    );
    emailController.dispose();
    return result ?? false;
  }

  /// Returns an OAuth access token with Classroom scopes, or null if cancelled.
  Future<String?> _ensureClassroomAccessToken({
    bool forceNonGooglePrompt = false,
  }) async {
    final linkedGoogle = _firebaseUserLinkedWithGoogle();
    final needSheet = !linkedGoogle &&
        (forceNonGooglePrompt || !_classroomConnectAcknowledged);
    if (needSheet) {
      if (!mounted) return null;
      final ok = await _showClassroomConnectDialog();
      if (!ok) return null;
    }

    final trySilent = linkedGoogle;
    var token = await GoogleAuthService.signInForClassroom(
      trySilentFirst: trySilent,
    );
    token ??= await GoogleAuthService.signInForClassroom(
      trySilentFirst: false,
    );
    if (token != null && !linkedGoogle) {
      _classroomConnectAcknowledged = true;
    }
    return token;
  }

  Future<void> _prepareSemesters() async {
    if (_isPreparingSemesters) return;
    setState(() => _isPreparingSemesters = true);
    try {
      final token = await _ensureClassroomAccessToken(
        forceNonGooglePrompt: false,
      );
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google sign-in cancelled')),
          );
        }
        return;
      }
      _accessToken = token;
      await _populateSemestersFromToken(token);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load semesters: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPreparingSemesters = false);
      }
    }
  }

  /// Returns `null` if semesters are ready to sync; otherwise a short user-facing message.
  Future<String?> _ensureSemestersLoadedForSync() async {
    if (_semesterOptions.isNotEmpty && _selectedSemesterId != null) {
      return null;
    }
    if (_isPreparingSemesters) {
      return 'Already loading semesters. Please wait.';
    }
    setState(() => _isPreparingSemesters = true);
    try {
      final token = await _ensureClassroomAccessToken(
        forceNonGooglePrompt: false,
      );
      if (token == null) {
        return 'Google sign-in was cancelled or did not return a token. '
            'On the web, add your OAuth web client ID and enable the Classroom API in Google Cloud Console.';
      }
      _accessToken = token;
      await _populateSemestersFromToken(token);
      if (_selectedSemesterId == null || _semesterOptions.isEmpty) {
        return 'Could not set a semester after loading courses. Try Load semesters again.';
      }
      return null;
    } catch (e) {
      return 'Failed to load courses from Google: $e';
    } finally {
      if (mounted) {
        setState(() => _isPreparingSemesters = false);
      }
    }
  }

  Future<void> _handleSync() async {
    final provider = context.read<ClassroomProvider>();
    if (provider.isLoading || _isPreparingSemesters) return;

    try {
      final needSemesters =
          _semesterOptions.isEmpty || _selectedSemesterId == null;
      if (needSemesters) {
        final semesterErr = await _ensureSemestersLoadedForSync();
        if (semesterErr != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(semesterErr)),
            );
          }
          return;
        }
      } else {
        final token = await _ensureClassroomAccessToken(
          forceNonGooglePrompt: false,
        );
        if (token == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Google sign-in cancelled')),
            );
          }
          return;
        }
        _accessToken = token;
      }

      await provider.syncClassroom(
        _accessToken!,
        semesterId: _selectedSemesterId,
      );

      if (!mounted) return;
      if (provider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: ${provider.error}')),
        );
        return;
      }

      final count = provider.tasks.length;
      final selectedLabel = _selectedSemesterLabel;
      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Synced $count assignments ($selectedLabel)',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sync complete for $selectedLabel. No assignments found for this semester.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _addManualCourse() async {
    final name = _manualCourseController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a course name')),
      );
      return;
    }
    await context.read<ClassroomProvider>().addManualCourse(name);
    if (!mounted) return;
    _manualCourseController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "$name"')),
    );
  }

  int _taskCount(ClassroomProvider p, String courseId) {
    return p.tasks.where((t) => t.courseId == courseId).length;
  }

  String _relativeSynced(DateTime? at) {
    if (at == null) return 'Never';
    final d = DateTime.now().difference(at);
    if (d.inSeconds < 45) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} minutes ago';
    if (d.inHours < 24) return '${d.inHours} hours ago';
    if (d.inDays < 7) return '${d.inDays} days ago';
    return '${(d.inDays / 7).floor()} weeks ago';
  }

  Widget _sectionTitle(BuildContext context, String text, UpGradeRem rem) {
    return Padding(
      padding: EdgeInsets.only(top: rem.space(0.45), bottom: rem.space(0.65)),
      child: Row(
        children: [
          Container(
            width: rem.space(0.22).clamp(3.0, 5.0),
            height: rem.space(1.35),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(3),
              boxShadow: AppTheme.softShadow,
            ),
          ),
          SizedBox(width: rem.space(0.55)),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                    fontSize: rem.sectionTitle,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _courseCard({
    required BuildContext context,
    required ClassroomCourse course,
    required int assignmentCount,
    required bool manual,
    required UpGradeRem rem,
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 10),
  }) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withOpacity(0.62);
    final isDark = theme.brightness == Brightness.dark;
    final sectionOrCode =
        (course.section != null && course.section!.trim().isNotEmpty)
            ? course.section!.trim()
            : (manual ? 'Manual' : 'Google Classroom');
    final subtitle =
        '$sectionOrCode · $assignmentCount ${assignmentCount == 1 ? 'assignment' : 'assignments'}';

    final accent = manual
        ? [const Color(0xFFF3E8FF), AppTheme.secondaryPurple]
        : _accentForCourseId(course.id);
    final softBg = accent[0];
    final bold = accent[1];

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E293B),
                  const Color(0xFF172033),
                ]
              : [
                  softBg,
                  Colors.white,
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bold.withOpacity(isDark ? 0.4 : 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: bold.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: rem.space(0.85),
          vertical: rem.space(0.65),
        ),
        child: Row(
          children: [
            Container(
              width: rem.iconSmall * 2.2,
              height: rem.iconSmall * 2.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: manual
                      ? [
                          AppTheme.secondaryPurple,
                          AppTheme.primaryBlue,
                        ]
                      : [
                          bold,
                          Color.lerp(bold, AppTheme.secondaryPurple, 0.35) ??
                              bold,
                        ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: bold.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                manual ? Icons.edit_note_rounded : Icons.check_rounded,
                color: Colors.white,
                size: rem.iconSmall * 1.05,
              ),
            ),
            SizedBox(width: rem.space(0.55)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: rem.listTitle,
                    ),
                  ),
                  SizedBox(height: rem.space(0.12)),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: rem.listSubtitle, color: muted),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: rem.space(0.55),
                    vertical: rem.space(0.28),
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        bold.withOpacity(0.12),
                        bold.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: bold.withOpacity(0.28)),
                  ),
                  child: Text(
                    manual ? 'Manual' : 'Synced',
                    style: TextStyle(
                      fontSize: rem.listSubtitle,
                      fontWeight: FontWeight.w700,
                      color: bold,
                    ),
                  ),
                ),
                if (manual)
                  IconButton(
                    tooltip: 'Remove course',
                    icon: Icon(
                      Icons.delete_outline,
                      color: AppTheme.errorRed.withOpacity(0.85),
                    ),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Remove course?'),
                          content: Text(
                            'Remove "${course.name}" and its manual tasks?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        await context
                            .read<ClassroomProvider>()
                            .removeManualCourse(course.id);
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(
    BuildContext context, {
    required ClassroomProvider provider,
    required bool hasClassroomCourses,
    required UpGradeRem rem,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(rem.space(1.05)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppTheme.primaryBlue.withOpacity(0.22),
                  AppTheme.secondaryPurple.withOpacity(0.18),
                  const Color(0xFF1E293B),
                ]
              : [
                  const Color(0xFFDBEAFE),
                  const Color(0xFFE9D5FF),
                  const Color(0xFFF0F9FF),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(isDark ? 0.45 : 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.14),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppTheme.secondaryPurple.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(rem.space(0.45)),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: rem.iconSmall * 1.35,
                ),
              ),
              SizedBox(width: rem.space(0.65)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasClassroomCourses
                          ? 'Connected to Google Classroom'
                          : 'Not connected to Google Classroom',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: rem.cardTitle,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: rem.space(0.25)),
                    Text(
                      hasClassroomCourses
                          ? 'Last synced: ${_relativeSynced(provider.syncedAt)}'
                          : 'Sign in with Google and sync to import enrolled courses.',
                      style: TextStyle(
                        fontSize: rem.cardBody,
                        color: theme.colorScheme.onSurface.withOpacity(0.72),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasClassroomCourses)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: rem.space(0.5),
                    vertical: rem.space(0.3),
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.successGreen.withOpacity(0.2),
                        const Color(0xFF34D399).withOpacity(0.25),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppTheme.successGreen.withOpacity(0.45),
                    ),
                  ),
                  child: Text(
                    'Active',
                    style: TextStyle(
                      fontSize: rem.listSubtitle,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? const Color(0xFF6EE7B7)
                          : const Color(0xFF047857),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: rem.space(0.85)),
          Row(
            children: [
              Expanded(
                child: _semesterControls(context, provider, rem),
              ),
              SizedBox(width: rem.space(0.55)),
              Consumer<ClassroomProvider>(
                builder: (context, p, _) {
                  final loading = p.isLoading || _isPreparingSemesters;
                  final labelStyle = TextStyle(
                    color: AppTheme.white,
                    fontWeight: FontWeight.w600,
                    fontSize: rem.buttonLabel,
                  );
                  return Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.mediumShadow,
                    ),
                    child: ElevatedButton.icon(
                      onPressed: loading ? null : _handleSync,
                      icon: loading
                          ? SizedBox(
                              width: rem.iconSmall,
                              height: rem.iconSmall,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.white,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.sync_rounded,
                              size: rem.iconSmall,
                              color: AppTheme.white,
                            ),
                      label: Text(
                        loading ? 'Syncing…' : 'Sync Now',
                        style: labelStyle,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppTheme.white,
                        disabledForegroundColor:
                            AppTheme.white.withOpacity(0.65),
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.symmetric(
                          horizontal: rem.space(0.75),
                          vertical: rem.space(0.55),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _semesterControls(
    BuildContext context,
    ClassroomProvider provider,
    UpGradeRem rem,
  ) {
    if (_semesterOptions.isNotEmpty) {
      return DropdownButtonFormField<String>(
        value: _selectedSemesterId,
        style: TextStyle(
          fontSize: rem.inputText,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          labelText: 'Semester',
          labelStyle: TextStyle(
            fontSize: rem.listSubtitle,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryBlue,
          ),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E293B).withOpacity(0.95)
              : const Color(0xFFF8FAFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppTheme.primaryBlue.withOpacity(0.25),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppTheme.secondaryPurple.withOpacity(0.22),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppTheme.secondaryPurple,
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: rem.space(0.75),
            vertical: rem.space(0.45),
          ),
        ),
        items: _semesterOptions
            .map(
              (s) => DropdownMenuItem<String>(
                value: s.id,
                child: Text(
                  s.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: rem.inputText),
                ),
              ),
            )
            .toList(),
        onChanged: provider.isLoading || _isPreparingSemesters
            ? null
            : (value) {
                if (value == null) return;
                setState(() => _selectedSemesterId = value);
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid != null) {
                  ClassroomStorageService.saveSelectedSemesterId(uid, value);
                }
              },
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withOpacity(0.12),
            AppTheme.secondaryPurple.withOpacity(0.12),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: OutlinedButton.icon(
          onPressed: provider.isLoading || _isPreparingSemesters
              ? null
              : _prepareSemesters,
          icon: _isPreparingSemesters
              ? SizedBox(
                  width: rem.iconSmall * 0.95,
                  height: rem.iconSmall * 0.95,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.school_rounded, size: rem.iconSmall),
          label: Text(
            _isPreparingSemesters ? 'Loading…' : 'Load semesters',
            style: TextStyle(
              fontSize: rem.buttonLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryBlue,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF111827)
                : Colors.white,
            side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.35)),
            padding: EdgeInsets.symmetric(
              horizontal: rem.space(0.75),
              vertical: rem.space(0.55),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.5),
            ),
          ),
        ),
      ),
    );
  }

  /// Max width of the white content card next to the sidebar (uses horizontal space on desktop).
  double _shellInnerMaxWidth(double bodyWidth) {
    if (bodyWidth <= 0) return 640;
    return (bodyWidth - 40).clamp(640.0, 1320.0);
  }

  Widget _courseCardsWrap({
    required BuildContext context,
    required ClassroomProvider provider,
    required List<ClassroomCourse> courses,
    required bool manual,
    required double columnWidth,
    required UpGradeRem rem,
  }) {
    const gap = 12.0;
    final useTwoCols = columnWidth >= 760 && courses.length > 1;
    final itemW = useTwoCols ? (columnWidth - gap) / 2 : columnWidth;

    return Wrap(
      spacing: gap,
      runSpacing: 12,
      children: courses
          .map(
            (c) => SizedBox(
              width: itemW,
              child: _courseCard(
                context: context,
                course: c,
                assignmentCount: _taskCount(provider, c.id),
                manual: manual,
                rem: rem,
                margin: EdgeInsets.zero,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required double innerWidth,
    required UpGradeRem rem,
  }) {
    return Consumer<ClassroomProvider>(
      builder: (context, provider, _) {
        final enrolled =
            provider.courses.where((c) => !c.id.startsWith('manual_')).toList();
        final manual =
            provider.courses.where((c) => c.id.startsWith('manual_')).toList();
        final hasClassroom = enrolled.isNotEmpty;
        final splitSideBySide = innerWidth >= 1080;

        final statusBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusCard(
              context,
              provider: provider,
              hasClassroomCourses: hasClassroom,
              rem: rem,
            ),
            SizedBox(height: rem.space(0.45)),
            Text(
              'Sync target: $_selectedSemesterLabel',
              style: TextStyle(
                fontSize: rem.listSubtitle,
                fontWeight: FontWeight.w600,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
          ],
        );

        Widget enrolledSection(double w) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle(context, 'Enrolled courses', rem),
              if (enrolled.isEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: rem.space(0.45)),
                  child: Text(
                    'No Classroom courses yet. Tap Sync Now to connect and import.',
                    style: TextStyle(
                      fontSize: rem.cardBody,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                      height: 1.4,
                    ),
                  ),
                )
              else
                _courseCardsWrap(
                  context: context,
                  provider: provider,
                  courses: enrolled,
                  manual: false,
                  columnWidth: w,
                  rem: rem,
                ),
            ],
          );
        }

        Widget manualSection(double w) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle(context, 'Manual courses', rem),
              UpGradeAccentStripeCard(
                rem: rem,
                isDark: Theme.of(context).brightness == Brightness.dark,
                stripeGradient: const [
                  AppTheme.secondaryPurple,
                  AppTheme.primaryBlue,
                ],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add a course that is not from Google Classroom',
                      style: TextStyle(
                        fontSize: rem.cardBody,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.65),
                      ),
                    ),
                    SizedBox(height: rem.space(0.55)),
                    TextField(
                      controller: _manualCourseController,
                      style: TextStyle(fontSize: rem.inputText),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addManualCourse(),
                      decoration: UpGradeInputDecor.themed(
                        context,
                        rem,
                        'e.g. Chemistry, Piano lessons',
                        prefix: Icon(
                          Icons.playlist_add_rounded,
                          size: rem.iconSmall,
                        ),
                        fillTint: AppTheme.secondaryPurple.withOpacity(0.08),
                      ),
                    ),
                    SizedBox(height: rem.space(0.55)),
                    UpGradeGradientFilledButton(
                      onPressed: _addManualCourse,
                      icon: Icon(Icons.add_rounded, size: rem.iconSmall),
                      label: Text(
                        'Add manual course',
                        style: TextStyle(
                          fontSize: rem.buttonLabel,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      padding: EdgeInsets.symmetric(vertical: rem.space(0.65)),
                    ),
                  ],
                ),
              ),
              if (manual.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: rem.space(0.65)),
                  child: Text(
                    'No manual courses yet. Add one above.',
                    style: TextStyle(
                      fontSize: rem.cardBody,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.only(top: rem.space(0.65)),
                  child: _courseCardsWrap(
                    context: context,
                    provider: provider,
                    courses: manual,
                    manual: true,
                    columnWidth: w,
                    rem: rem,
                  ),
                ),
            ],
          );
        }

        if (splitSideBySide) {
          final gap = rem.space(1.1);
          final col = (innerWidth - gap) / 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              statusBlock,
              SizedBox(height: rem.space(0.85)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: enrolledSection(col)),
                  SizedBox(width: gap),
                  Expanded(child: manualSection(col)),
                ],
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            statusBlock,
            enrolledSection(innerWidth),
            manualSection(innerWidth),
          ],
        );
      },
    );
  }

  Widget _postLoginSetupBanner() {
    if (!widget.fromPostLoginSetup) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(
          isDark ? 0.32 : 0.72,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.phone_android_rounded,
                color: theme.colorScheme.primary,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'When you are ready, continue to scan the QR code and finish setup.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: () {
              context
                  .read<DashboardShellProvider>()
                  .setGoogleClassroomFromPostLoginSetup(false);
              Navigator.of(context).pushReplacementNamed(
                AppConstants.routeDevicePairing,
              );
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            label: const Text('Continue to device pairing'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;

    if (wide) {
      final theme = Theme.of(context);
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxCard = _shellInnerMaxWidth(constraints.maxWidth);
              final hPad = constraints.maxWidth > 1100 ? 28.0 : 20.0;
              final vPad = constraints.maxHeight > 800 ? 20.0 : 16.0;
              final titleAlign =
                  maxCard > 960 ? TextAlign.start : TextAlign.center;
              final isDark = theme.brightness == Brightness.dark;
              final rem = UpGradeRem(maxCard);
              final innerContentW =
                  (maxCard - rem.space(1.2) * 2 - 4).clamp(260.0, 2000.0);
              final bodyRem = UpGradeRem(innerContentW);
              final titleAlignment = titleAlign == TextAlign.center
                  ? Alignment.center
                  : Alignment.centerLeft;

              return SingleChildScrollView(
                padding:
                    EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxCard,
                      minHeight: constraints.maxHeight - vPad * 2,
                    ),
                    child: UpGradeGradientFrameCard(
                      rem: rem,
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: Align(
                              alignment: titleAlignment,
                              child: UpGradeGradientTitle(
                                'Google Classroom Sync',
                                rem: rem,
                                isDark: isDark,
                              ),
                            ),
                          ),
                          SizedBox(height: rem.space(0.35)),
                          SizedBox(
                            width: double.infinity,
                            child: Align(
                              alignment: titleAlignment,
                              child: UpGradeMutedSubtitle(
                                _pageSubtitle,
                                rem: rem,
                                isDark: isDark,
                              ),
                            ),
                          ),
                          SizedBox(height: rem.space(1.0)),
                          if (widget.fromPostLoginSetup) ...[
                            _postLoginSetupBanner(),
                            SizedBox(height: rem.space(0.85)),
                          ],
                          _buildBody(
                            context,
                            innerWidth: innerContentW,
                            rem: bodyRem,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    final narrowW = MediaQuery.sizeOf(context).width;
    final narrowInner = (narrowW - 48).clamp(280.0, 520.0);

    return UpGradePageShell(
      title: 'Google Classroom Sync',
      subtitle: _pageSubtitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.fromPostLoginSetup) ...[
            _postLoginSetupBanner(),
            const SizedBox(height: 20),
          ],
          _buildBody(
            context,
            innerWidth: narrowInner,
            rem: UpGradeRem(narrowInner),
          ),
        ],
      ),
    );
  }

  String get _selectedSemesterLabel {
    final selected = _semesterOptions.cast<SemesterOption?>().firstWhere(
          (s) => s?.id == _selectedSemesterId,
          orElse: () => null,
        );
    if (selected != null) return selected.label;
    return _selectedSemesterId == SemesterFilterService.unknownSemesterId
        ? SemesterFilterService.unknownSemesterLabel
        : 'Not selected';
  }
}
