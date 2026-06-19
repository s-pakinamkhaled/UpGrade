// ═══════════════════════════════════════════════════════════════════
// SCREEN: AI Study Plan Generator
// ═══════════════════════════════════════════════════════════════════
//
// DESCRIPTION
// -----------
// Generates and displays a personalised multi-day study plan created by
// Llama 3.3 (70B) via Groq. The plan is based entirely on the student's
// real Google Classroom assignments — deadlines, priorities, estimated
// effort, grades, and course names are all sent to the AI so that every
// time-slot suggestion is specific and actionable.
//
// HOW TO REACH THIS SCREEN
// ------------------------
// My Tasks screen → tap the "Generate AI Plan" button
// → selectMainShellRoute(context, AppConstants.routeStudyPlan)
// → this screen opens and immediately starts generating.
//
// WORKFLOW
// --------
// 1. INIT  →  initState() calls _generate() immediately on open.
//
// 2. DATA COLLECTION  →  _generate()
//      a) Reads all tasks from ClassroomProvider
//         (populated by Google Classroom sync).
//      b) Filters to only pending / inProgress tasks — completed tasks
//         are excluded so the plan stays relevant.
//      c) Gets the student's display name from FirebaseAuth.
//
// 3. API CALL  →  ApiService().generateStudyPlan()
//      POST /api/plan/generate  (60-second timeout)
//      Payload:
//        studentName  : string
//        tasks[]      : [{id, title, courseName, deadline,
//                        estimatedMinutes, priority, status,
//                        description, assignedGrade, maxPoints}]
//
// 4. BACKEND PROCESSING  (backend/app/api/routes/planner.py)
//      a) Filters completed tasks.
//      b) Sorts by priority (urgent→high→medium→low) then by deadline.
//      c) Trims to 15 most urgent tasks.
//      d) Builds a detailed prompt listing each task with days-left,
//         grade info, and time estimates.
//      e) Calls Groq API (llama-3.3-70b-versatile, temp=0.4,
//         max_tokens=3000) with strict JSON-only instruction.
//      f) Parses and validates the JSON response into PlanItem objects.
//
// 5. RESPONSE  →  StudyPlan.fromJson(response)
//      Deserialises into StudyPlan model containing:
//        - studentName, generatedAt, summary
//        - items[]{taskTitle, courseName, suggestedDate, suggestedTime,
//                  hoursNeeded, priority, tip}
//
// 6. RENDERING
//      _buildSummaryCard()   — gradient header with name, timestamp &
//                              the AI's 2-3 sentence summary
//      _buildPlanItemCard()  — one card per task, colour-coded border by
//                              priority, info chips (date, time, hours,
//                              course), and the AI-generated study tip
//      Regenerate button     — calls _generate() again for a fresh plan
//
// STATES
// ------
// _loading=true  → shows spinner + "Generating your study plan..."
// _plan≠null     → shows full plan UI (Upcoming Tasks uses plan items when present)
// ═══════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../models/task.dart';
import '../models/study_plan.dart';
import '../providers/classroom_provider.dart';
import '../services/api_service.dart';
import '../widgets/dashboard_secondary_shell.dart';
import '../widgets/upgrade_visual_system.dart';

/// Study Plan page matching the dashboard design: header, summary cards,
/// My Courses / Upcoming Tasks tabs, course cards with gradient progress,
/// and AI recommendation card.
class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({super.key});

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  int _tabIndex = 0; // 0 = My Courses, 1 = Upcoming Tasks
  bool _loading = true;

  /// True while a backend request is in flight. Prevents concurrent requests
  /// that would hit the LLM rate limit and both fail.
  bool _isGenerating = false;

  StudyPlan? _plan;
  String? _generateError;

  /// How the AI finish scenario is grouped (user-customizable view).
  _PlanGrouping _grouping = _PlanGrouping.day;

  /// Default hours/day the student wants to study. Customizable + persisted.
  double _defaultDailyHours = 4.0;

  /// Per-day capacity overrides keyed by 'yyyy-MM-dd' (e.g. today 5h, tomorrow 3h).
  final Map<String, double> _dayHourOverrides = {};

  static const String _capacityPrefsKey = 'study_plan_capacity';

  @override
  void initState() {
    super.initState();
    _loadCapacityThenGenerate();
  }

  Future<void> _loadCapacityThenGenerate() async {
    await _loadCapacity();
    await _generate();
  }

  String get _capacityStorageKey {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    return '${_capacityPrefsKey}_$uid';
  }

  Future<void> _loadCapacity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_capacityStorageKey);
      if (raw == null || raw.isEmpty) return;
      final data = json.decode(raw) as Map<String, dynamic>;
      final def = (data['default'] as num?)?.toDouble();
      if (def != null) _defaultDailyHours = def.clamp(0.5, 16.0);
      final overrides = data['overrides'] as Map<String, dynamic>?;
      if (overrides != null) {
        _dayHourOverrides.clear();
        overrides.forEach((k, v) {
          final h = (v as num?)?.toDouble();
          if (h != null) _dayHourOverrides[k] = h.clamp(0.0, 16.0);
        });
      }
    } catch (_) {
      // Corrupt or missing config — fall back to defaults silently.
    }
  }

  Future<void> _saveCapacity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _capacityStorageKey,
        json.encode({
          'default': _defaultDailyHours,
          'overrides': _dayHourOverrides,
        }),
      );
    } catch (_) {
      // Persistence is best-effort; ignore failures.
    }
  }

  Future<void> _generate() async {
    // Prevent concurrent requests: if one is already in flight, do nothing.
    // This is the first line of defence against rate-limit bursts when the
    // user taps "Regenerate" rapidly.
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
      _loading = true;
      _plan = null;
      _generateError = null;
    });

    try {
      final provider = context.read<ClassroomProvider>();
      // Send ALL actionable tasks (including missed/overdue) to the AI planner
      // so it can schedule catch-up work alongside upcoming assignments.
      final activeTasks = provider.actionableTasksForAI;

      final user = FirebaseAuth.instance.currentUser;
      final studentName =
          user?.displayName ?? user?.email?.split('@').first ?? 'Student';

      final response = await ApiService().generateStudyPlan(
        studentName: studentName,
        tasks: activeTasks,
        defaultDailyHours: _defaultDailyHours,
        dailyHours: Map<String, double>.from(_dayHourOverrides),
      );

      if (!mounted) return;

      if (response != null) {
        setState(() {
          _plan = StudyPlan.fromJson(response);
          _loading = false;
          _isGenerating = false;
        });
      } else {
        setState(() {
          _loading = false;
          _isGenerating = false;
          _generateError =
              'The AI planner did not return a plan. Please try again in a moment.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      String userMessage;
      if (msg.contains('502') || msg.contains('rate') || msg.contains('429')) {
        userMessage =
            'The AI service is busy right now. Please wait a few seconds and try again.';
      } else if (msg.contains('503') || msg.contains('unavailable')) {
        userMessage = 'AI service is temporarily unavailable. Try again shortly.';
      } else {
        userMessage = 'Could not generate a plan. Please try again.';
      }
      setState(() {
        _loading = false;
        _isGenerating = false;
        _generateError = userMessage;
      });
    }
  }

  Future<void> _pickTaskDeadline(BuildContext context, Task task) async {
    final provider = context.read<ClassroomProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final initial = task.hasRealDeadline && task.deadline.isAfter(now)
        ? task.deadline
        : now.add(const Duration(days: 1));
    final firstDate = DateTime(now.year, now.month, now.day);

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: firstDate,
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: task.hasRealDeadline ? 'Edit deadline' : 'Set deadline',
    );
    if (selectedDate == null || !context.mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Choose finish time',
    );
    if (selectedTime == null || !context.mounted) return;

    final deadline = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    await provider.updateTaskDeadline(
      task.id,
      deadline,
    );
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text('Deadline saved for ${task.title}. Regenerating plan.'),
      ),
    );
    await _generate();
  }

  /// Generic hour-picker bottom sheet. Returns the chosen hours, or null.
  Future<double?> _pickHours({
    required String title,
    required String subtitle,
    required double current,
    bool allowZero = false,
  }) async {
    final presets = <double>[
      if (allowZero) 0,
      0.5,
      1,
      1.5,
      2,
      3,
      4,
      5,
      6,
      8,
    ];
    return showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.65),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presets.map((h) {
                    final selected = (h - current).abs() < 0.01;
                    final label = h == 0
                        ? 'Skip (0h)'
                        : (h == h.truncateToDouble()
                            ? '${h.toInt()}h'
                            : '${h}h');
                    return ChoiceChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) => Navigator.of(ctx).pop(h),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Edit a single task's expected time-to-finish, then regenerate the plan.
  Future<void> _editTaskHours(BuildContext context, Task task) async {
    final provider = context.read<ClassroomProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final currentHours = (task.estimatedMinutes / 60.0);
    final picked = await _pickHours(
      title: 'Time to finish',
      subtitle: 'How long do you expect "${task.title}" to take?',
      current: currentHours,
    );
    if (picked == null || !context.mounted) return;

    final minutes = (picked * 60).round();
    if (minutes == task.estimatedMinutes) return;

    await provider.updateTaskEstimatedMinutes(task.id, minutes);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Updated expected time for ${task.title}. Regenerating plan.'),
      ),
    );
    await _generate();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final secondary = isDark ? const Color(0xFF9CA3AF) : AppTheme.mediumGray;

    Widget planContent() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final rawW = constraints.maxWidth;
          final layoutW = rawW.isFinite && rawW > 0
              ? rawW
              : MediaQuery.sizeOf(context).width - 48;
          final rem = UpGradeRem(layoutW);

          return Consumer<ClassroomProvider>(
            builder: (context, provider, _) {
              // Use all actionable tasks (including missed) for the plan table
              // so every incomplete assignment is visible to the student.
              final planningTasks = provider.actionableTasksForAI;
              final stats = _computeStats(planningTasks);
              final courseStats = _computeCourseStats(planningTasks);
              final upcomingTasks = _upcomingTasks(planningTasks);

              if (_loading && _plan == null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: _buildLoading(rem: rem, isDark: isDark),
                );
              }

              // Show a friendly error banner if plan generation failed.
              if (_generateError != null && _plan == null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed.withOpacity(isDark ? 0.18 : 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.errorRed.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: AppTheme.errorRed, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Plan generation failed',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: rem.listTitle,
                                      color: AppTheme.errorRed,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _generateError!,
                                    style: TextStyle(
                                      fontSize: rem.listSubtitle,
                                      color: onSurface.withOpacity(0.8),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      UpGradeGradientFilledButton(
                        onPressed: _isGenerating ? null : _generate,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Try Again'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, isDark, rem),
                  if (_plan?.degraded == true) ...[
                    SizedBox(height: rem.space(1.0)),
                    _buildDegradedNotice(rem: rem, isDark: isDark),
                  ],
                  SizedBox(height: rem.space(1.65)),
                  _buildSummaryCards(
                    context,
                    rem: rem,
                    isDark: isDark,
                    stats: stats,
                    courseCount: courseStats.length,
                    secondary: secondary,
                  ),
                  SizedBox(height: rem.space(1.4)),
                  _buildDailyCapacitySection(
                    context,
                    rem: rem,
                    isDark: isDark,
                    onSurface: onSurface,
                    secondary: secondary,
                  ),
                  SizedBox(height: rem.space(1.4)),
                  _buildTabBar(
                    context,
                    rem: rem,
                    isDark: isDark,
                    surface: surface,
                    onSurface: onSurface,
                  ),
                  SizedBox(height: rem.space(1.15)),
                  if (_tabIndex == 0)
                    _buildMyCourses(
                      context,
                      rem: rem,
                      isDark: isDark,
                      courseStats: courseStats,
                      onSurface: onSurface,
                      secondary: secondary,
                    )
                  else
                    _buildUpcomingTasks(
                      context,
                      rem: rem,
                      isDark: isDark,
                      plan: _plan,
                      fallbackTasks: upcomingTasks,
                      onSurface: onSurface,
                      secondary: secondary,
                    ),
                  if (_plan != null && _plan!.summary.isNotEmpty) ...[
                    SizedBox(height: rem.space(1.4)),
                    _buildAIRecommendationCard(
                      context,
                      rem: rem,
                      isDark: isDark,
                      plan: _plan!,
                      onSurface: onSurface,
                      secondary: secondary,
                    ),
                  ],
                  SizedBox(height: rem.space(1.85)),
                ],
              );
            },
          );
        },
      );
    }

    final narrow = Scaffold(
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
      body: DecoratedBox(
        decoration: UpGradePageDecor.pageBackground(isDark),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: planContent(),
        ),
      ),
    );

    return DashboardSecondaryShell(
      narrow: narrow,
      wideBody: DecoratedBox(
        decoration: UpGradePageDecor.pageBackground(isDark),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: planContent(),
        ),
      ),
    );
  }

  /// Subtle banner shown when the plan was built locally (AI rate-limited).
  Widget _buildDegradedNotice({
    required UpGradeRem rem,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.all(rem.space(0.85)),
      decoration: BoxDecoration(
        color: AppTheme.warningOrange.withOpacity(isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningOrange.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.offline_bolt_rounded,
              color: AppTheme.warningOrange, size: 20),
          SizedBox(width: rem.space(0.6)),
          Expanded(
            child: Text(
              'The AI service was busy, so this plan was built automatically '
              'from your deadlines. It is complete and ordered — tap '
              '"Create New Plan" in a moment for AI-written tips.',
              style: TextStyle(
                fontSize: rem.listSubtitle,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    UpGradeRem rem,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        final titleSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            UpGradeGradientTitle('Study Plan', rem: rem, isDark: isDark),
            SizedBox(height: rem.space(0.45)),
            UpGradeMutedSubtitle(
              'AI-powered personalized study schedule',
              rem: rem,
              isDark: isDark,
            ),
          ],
        );
        final button = UpGradeGradientFilledButton(
          // Disable while a request is in flight so the user cannot fire
          // concurrent calls that would hit the LLM rate limit.
          onPressed: (_loading || _isGenerating) ? null : _generate,
          icon: Icon(
            _isGenerating ? Icons.hourglass_top_rounded : Icons.add,
            size: 20,
          ),
          label: Text(_isGenerating ? 'Generating…' : 'Create New Plan'),
          padding: EdgeInsets.symmetric(
            horizontal: rem.space(1.35),
            vertical: rem.space(0.85),
          ),
        );
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleSection,
              SizedBox(height: rem.space(1.0)),
              button,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: titleSection),
            button,
          ],
        );
      },
    );
  }

  Widget _buildSummaryCards(
    BuildContext context, {
    required UpGradeRem rem,
    required bool isDark,
    required _StudyPlanStats stats,
    required int courseCount,
    required Color secondary,
  }) {
    final hoursThisWeek = stats.hoursThisWeek;
    final hoursStr = hoursThisWeek >= 1
        ? '${hoursThisWeek.toStringAsFixed(0)} hours'
        : '${(hoursThisWeek * 60).toInt()} min';
    final completionStr = stats.total == 0
        ? '0%'
        : '${(stats.completionRate * 100).toStringAsFixed(1)}%';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        if (isNarrow) {
          return Column(
            children: [
              _statCard(
                context,
                rem: rem,
                isDark: isDark,
                icon: Icons.calendar_today,
                iconBg: AppTheme.primaryBlue.withOpacity(0.12),
                iconColor: AppTheme.primaryBlue,
                label: 'This Week',
                value: hoursStr,
                secondary: secondary,
              ),
              SizedBox(height: rem.space(0.75)),
              _statCard(
                context,
                rem: rem,
                isDark: isDark,
                icon: Icons.menu_book,
                iconBg: AppTheme.secondaryPurple.withOpacity(0.12),
                iconColor: AppTheme.secondaryPurple,
                label: 'Active Courses',
                value: '$courseCount',
                secondary: secondary,
              ),
              SizedBox(height: rem.space(0.75)),
              _statCard(
                context,
                rem: rem,
                isDark: isDark,
                icon: Icons.flag,
                iconBg: AppTheme.successGreen.withOpacity(0.12),
                iconColor: AppTheme.successGreen,
                label: 'Completion',
                value: completionStr,
                secondary: secondary,
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: _statCard(
                context,
                rem: rem,
                isDark: isDark,
                icon: Icons.calendar_today,
                iconBg: AppTheme.primaryBlue.withOpacity(0.12),
                iconColor: AppTheme.primaryBlue,
                label: 'This Week',
                value: hoursStr,
                secondary: secondary,
              ),
            ),
            SizedBox(width: rem.space(1.0)),
            Expanded(
              child: _statCard(
                context,
                rem: rem,
                isDark: isDark,
                icon: Icons.menu_book,
                iconBg: AppTheme.secondaryPurple.withOpacity(0.12),
                iconColor: AppTheme.secondaryPurple,
                label: 'Active Courses',
                value: '$courseCount',
                secondary: secondary,
              ),
            ),
            SizedBox(width: rem.space(1.0)),
            Expanded(
              child: _statCard(
                context,
                rem: rem,
                isDark: isDark,
                icon: Icons.flag,
                iconBg: AppTheme.successGreen.withOpacity(0.12),
                iconColor: AppTheme.successGreen,
                label: 'Completion',
                value: completionStr,
                secondary: secondary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statCard(
    BuildContext context, {
    required UpGradeRem rem,
    required bool isDark,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
    required Color secondary,
  }) {
    final valueFg = isDark ? Colors.white : iconColor;

    return Container(
      padding: EdgeInsets.all(rem.space(1.15)),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E293B),
                  iconColor.withOpacity(0.14),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  iconBg,
                  Colors.white,
                ],
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: iconColor.withOpacity(isDark ? 0.45 : 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(isDark ? 0.22 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(rem.space(0.65)),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              border: Border.all(color: iconColor.withOpacity(0.22)),
            ),
            child: Icon(icon, color: iconColor, size: rem.iconSmall * 1.05),
          ),
          SizedBox(height: rem.space(0.85)),
          Text(
            label,
            style: TextStyle(
              fontSize: rem.listSubtitle,
              color: secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: rem.space(0.25)),
          Text(
            value,
            style: TextStyle(
              fontSize: rem.cardTitle * 1.35,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.45,
              color: valueFg,
            ),
          ),
        ],
      ),
    );
  }

  // ── Daily study capacity UI ────────────────────────────────────────────────

  /// Hour options available in per-day capacity pickers (2 h → 20 h).
  static const List<double> _capacityHourOptions = [
    2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 16, 18, 20
  ];

  /// Opens a bottom sheet with 2 h – 20 h chip options for picking a specific
  /// day's study capacity. Returns the chosen hours, or null if dismissed.
  Future<double?> _pickCapacityHoursSheet({
    required String title,
    required String subtitle,
    required double current,
    bool allowSkip = false,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.65),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (allowSkip)
                      ChoiceChip(
                        label: const Text('Skip (0 h)'),
                        selected: current == 0,
                        onSelected: (_) => Navigator.of(ctx).pop(0.0),
                      ),
                    ..._capacityHourOptions.map((h) {
                      final selected = (h - current).abs() < 0.01;
                      return ChoiceChip(
                        label: Text('${h.toInt()} h'),
                        selected: selected,
                        onSelected: (_) => Navigator.of(ctx).pop(h),
                        selectedColor: AppTheme.secondaryPurple,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? Colors.white
                              : (isDark
                                  ? Colors.white
                                  : AppTheme.darkText),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Inline section that lets the student set their default daily study
  /// capacity (2–20 h) and inspect or clear per-day overrides.
  Widget _buildDailyCapacitySection(
    BuildContext context, {
    required UpGradeRem rem,
    required bool isDark,
    required Color onSurface,
    required Color secondary,
  }) {
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;

    return Container(
      padding: EdgeInsets.all(rem.space(1.0)),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryPurple.withOpacity(isDark ? 0.12 : 0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: Colors.white,
                  size: rem.iconSmall,
                ),
              ),
              SizedBox(width: rem.space(0.65)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Study Hours',
                      style: TextStyle(
                        fontSize: rem.cardTitle,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: onSurface,
                      ),
                    ),
                    Text(
                      'Personalize how many hours you can study each day',
                      style: TextStyle(
                        fontSize: rem.listSubtitle * 0.95,
                        color: secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_defaultDailyHours.toInt()} h/day',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: rem.space(0.65)),
          Text(
            'Default (applies to all days without a custom setting):',
            style: TextStyle(
              fontSize: rem.listSubtitle,
              color: secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: rem.space(0.55)),
          // ── Inline chip row for default hours ────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _capacityHourOptions.map((h) {
                final selected = (h - _defaultDailyHours).abs() < 0.01;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _isGenerating
                          ? null
                          : () async {
                              if (selected) return;
                              setState(() => _defaultDailyHours = h);
                              await _saveCapacity();
                              await _generate();
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: selected ? AppTheme.primaryGradient : null,
                          color: selected
                              ? null
                              : (isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? Colors.transparent
                                : AppTheme.primaryBlue.withOpacity(0.22),
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.secondaryPurple
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : null,
                        ),
                        child: Text(
                          '${h.toInt()} h',
                          style: TextStyle(
                            fontSize: rem.listTitle,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // ── Per-day overrides ────────────────────────────────────────
          if (_dayHourOverrides.isNotEmpty) ...[
            SizedBox(height: rem.space(0.75)),
            Divider(
              color: border,
              height: 1,
            ),
            SizedBox(height: rem.space(0.65)),
            Text(
              'Custom days (tap × to reset to default):',
              style: TextStyle(
                fontSize: rem.listSubtitle,
                color: secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: rem.space(0.5)),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _dayHourOverrides.entries.map((entry) {
                return Chip(
                  avatar: Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: AppTheme.secondaryPurple,
                  ),
                  label: Text(
                    '${_dayHeaderLabel(entry.key)}: ${entry.value.toInt()} h',
                    style: TextStyle(
                      fontSize: rem.listSubtitle,
                      fontWeight: FontWeight.w700,
                      color: onSurface,
                    ),
                  ),
                  deleteIcon: const Icon(Icons.close_rounded, size: 14),
                  onDeleted: () async {
                    setState(() => _dayHourOverrides.remove(entry.key));
                    await _saveCapacity();
                    await _generate();
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar(
    BuildContext context, {
    required UpGradeRem rem,
    required bool isDark,
    required Color surface,
    required Color onSurface,
  }) {
    return Container(
      padding: EdgeInsets.all(rem.space(0.35)),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                colors: [
                  const Color(0xFF1E293B),
                  const Color(0xFF111827),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryBlue.withOpacity(0.1),
                  AppTheme.secondaryPurple.withOpacity(0.08),
                ],
              ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(isDark ? 0.35 : 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabChip(
              rem: rem,
              isDark: isDark,
              label: 'My Courses',
              selected: _tabIndex == 0,
              onTap: () => setState(() => _tabIndex = 0),
              surface: surface,
              onSurface: onSurface,
            ),
          ),
          Expanded(
            child: _tabChip(
              rem: rem,
              isDark: isDark,
              label: 'Upcoming Tasks',
              selected: _tabIndex == 1,
              onTap: () => setState(() => _tabIndex = 1),
              surface: surface,
              onSurface: onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip({
    required UpGradeRem rem,
    required bool isDark,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color surface,
    required Color onSurface,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppTheme.primaryBlue.withOpacity(0.12),
        highlightColor: AppTheme.secondaryPurple.withOpacity(0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(vertical: rem.space(0.75)),
          decoration: BoxDecoration(
            gradient: selected
                ? (isDark
                    ? LinearGradient(
                        colors: [
                          const Color(0xFF334155),
                          const Color(0xFF1E293B),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          const Color(0xFFF5F3FF),
                        ],
                      ))
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(
                    color:
                        AppTheme.primaryBlue.withOpacity(isDark ? 0.5 : 0.28),
                  )
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color:
                          AppTheme.primaryBlue.withOpacity(isDark ? 0.2 : 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: AppTheme.secondaryPurple.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: rem.listTitle,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, UpGradeRem rem, Color onSurface) {
    return Row(
      children: [
        Container(
          width: 4,
          height: rem.sectionTitle * 1.25,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: AppTheme.primaryGradient,
            boxShadow: AppTheme.softShadow,
          ),
        ),
        SizedBox(width: rem.space(0.7)),
        Text(
          title,
          style: TextStyle(
            fontSize: rem.sectionTitle * 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
            color: onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildMyCourses(
    BuildContext context, {
    required UpGradeRem rem,
    required bool isDark,
    required List<_CourseStat> courseStats,
    required Color onSurface,
    required Color secondary,
  }) {
    if (courseStats.isEmpty) {
      return _emptySection(
        context,
        rem: rem,
        isDark: isDark,
        icon: Icons.menu_book,
        message: 'No courses yet. Sync Google Classroom or add tasks.',
        secondary: secondary,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('My Courses', rem, onSurface),
        SizedBox(height: rem.space(1.0)),
        ...courseStats.map(
          (c) => Padding(
            padding: EdgeInsets.only(bottom: rem.space(1.0)),
            child: _courseCard(
              context,
              rem: rem,
              isDark: isDark,
              course: c,
              onSurface: onSurface,
              secondary: secondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _courseCard(
    BuildContext context, {
    required UpGradeRem rem,
    required bool isDark,
    required _CourseStat course,
    required Color onSurface,
    required Color secondary,
  }) {
    final progress = course.total == 0 ? 0.0 : course.completed / course.total;
    final code = _courseCode(course.courseName);
    final hoursPerWeek =
        (course.total * 30 / 60).ceil(); // rough: 30 min per task

    return Container(
      padding: EdgeInsets.all(rem.space(1.15)),
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
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE8E0EF),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(isDark ? 0.14 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppTheme.secondaryPurple.withOpacity(isDark ? 0.1 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.courseName,
                      style: TextStyle(
                        fontSize: rem.cardTitle * 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: onSurface,
                      ),
                    ),
                    SizedBox(height: rem.space(0.35)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: rem.space(0.45),
                        vertical: rem.space(0.25),
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.primaryBlue.withOpacity(0.22),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withOpacity(0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        code,
                        style: TextStyle(
                          fontSize: rem.listSubtitle,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.edit_outlined,
                    size: rem.iconSmall, color: secondary),
                tooltip: 'Edit',
              ),
            ],
          ),
          SizedBox(height: rem.space(1.0)),
          Row(
            children: [
              Icon(Icons.schedule,
                  size: rem.listSubtitle * 1.1, color: secondary),
              SizedBox(width: rem.space(0.35)),
              Text(
                '${hoursPerWeek}h/week',
                style: TextStyle(
                    fontSize: rem.listSubtitle,
                    color: secondary,
                    fontWeight: FontWeight.w500),
              ),
              SizedBox(width: rem.space(1.15)),
              Icon(Icons.flag, size: rem.listSubtitle * 1.1, color: secondary),
              SizedBox(width: rem.space(0.35)),
              Text(
                '${(progress * 100).toInt()}% complete',
                style: TextStyle(
                    fontSize: rem.listSubtitle,
                    color: secondary,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          SizedBox(height: rem.space(0.85)),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 10,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = progress.clamp(0.0, 1.0) * constraints.maxWidth;
                  return Stack(
                    children: [
                      Container(
                        width: constraints.maxWidth,
                        color: secondary.withOpacity(0.18),
                      ),
                      SizedBox(
                        width: w,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          SizedBox(height: rem.space(0.75)),
          Wrap(
            spacing: rem.space(0.45),
            runSpacing: rem.space(0.45),
            children: [
              _scheduleChip('Mon 9-11 AM', 0, rem, isDark),
              _scheduleChip('Wed 2-4 PM', 1, rem, isDark),
              _scheduleChip('Fri 10-12 PM', 2, rem, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scheduleChip(String label, int variant, UpGradeRem rem, bool isDark) {
    final accents = [
      (
        AppTheme.primaryBlue,
        isDark
            ? AppTheme.primaryBlue.withOpacity(0.18)
            : const Color(0xFFEFF6FF),
      ),
      (
        AppTheme.secondaryPurple,
        isDark
            ? AppTheme.secondaryPurple.withOpacity(0.18)
            : const Color(0xFFF5F3FF),
      ),
      (
        AppTheme.successGreen,
        isDark
            ? AppTheme.successGreen.withOpacity(0.18)
            : const Color(0xFFECFDF5),
      ),
    ];
    final i = variant % accents.length;
    final fg = accents[i].$1;
    final bg = accents[i].$2;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: rem.space(0.55),
        vertical: rem.space(0.35),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: fg.withOpacity(0.07),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: rem.listSubtitle * 0.95,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  String _courseCode(String name) {
    if (name.isEmpty) return '—';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0].substring(0, 1).toUpperCase()}${parts[1].substring(0, parts[1].length >= 3 ? 3 : parts[1].length).toUpperCase()}';
    }
    return name.length >= 6
        ? name.substring(0, 6).toUpperCase()
        : name.toUpperCase();
  }

  Widget _buildUpcomingTasks(
    BuildContext context, {
    required UpGradeRem rem,
    required bool isDark,
    StudyPlan? plan,
    required List<Task> fallbackTasks,
    required Color onSurface,
    required Color secondary,
  }) {
    final items = plan?.items ?? [];
    final planById = <String, StudyPlanItem>{};
    final planByTitle = <String, StudyPlanItem>{};
    for (final item in items) {
      final id = item.taskId?.trim();
      if (id != null && id.isNotEmpty) {
        planById[id] = item;
      }
      final title = item.taskTitle.trim().toLowerCase();
      if (title.isNotEmpty) {
        planByTitle[title] = item;
      }
    }

    if (fallbackTasks.isEmpty) {
      return _emptySection(
        context,
        rem: rem,
        isDark: isDark,
        icon: Icons.assignment_outlined,
        message: 'No upcoming tasks. Create a plan or add assignments.',
        secondary: secondary,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Personalized Task Plan', rem, onSurface),
        SizedBox(height: rem.space(1.0)),
        _planningTable(
          context,
          rem: rem,
          isDark: isDark,
          tasks: fallbackTasks,
          planById: planById,
          planByTitle: planByTitle,
          onSurface: onSurface,
          secondary: secondary,
        ),
        if (items.isNotEmpty) ...[
          SizedBox(height: rem.space(1.25)),
          Row(
            children: [
              Expanded(
                child: _sectionTitle(
                  'AI Finish Scenario — day by day',
                  rem,
                  onSurface,
                ),
              ),
              _groupingToggle(rem: rem, isDark: isDark, onSurface: onSurface),
            ],
          ),
          SizedBox(height: rem.space(0.4)),
          Text(
            _grouping == _PlanGrouping.day
                ? 'A realistic schedule: what to finish today, tomorrow, and beyond.'
                : _grouping == _PlanGrouping.priority
                    ? 'Tasks grouped by how urgent they are.'
                    : 'Tasks grouped by course.',
            style: TextStyle(
              fontSize: rem.listSubtitle,
              color: secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: rem.space(0.85)),
          ..._buildGroupedSchedule(
            context,
            rem: rem,
            isDark: isDark,
            items: items,
            onSurface: onSurface,
            secondary: secondary,
          ),
        ],
        if (items.isEmpty && _loading)
          ...fallbackTasks.take(10).map(
            (task) {
              final days = task.deadline.difference(DateTime.now()).inDays;
              final dueText = days < 0
                  ? 'Overdue'
                  : days == 0
                      ? 'Due today'
                      : 'Due in $days days';
              return Padding(
                padding: EdgeInsets.only(bottom: rem.space(0.75)),
                child: _upcomingTaskCard(
                  context,
                  rem: rem,
                  isDark: isDark,
                  title: task.title,
                  courseName: task.courseName.trim().isNotEmpty
                      ? task.courseName.trim()
                      : '—',
                  dueText: dueText,
                  priority: task.priority.name,
                  onSurface: onSurface,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _planningTable(
    BuildContext context, {
    required UpGradeRem rem,
    required bool isDark,
    required List<Task> tasks,
    required Map<String, StudyPlanItem> planById,
    required Map<String, StudyPlanItem> planByTitle,
    required Color onSurface,
    required Color secondary,
  }) {
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final headerBg = isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
    final rowBg = isDark ? const Color(0xFF0F172A) : Colors.white;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(isDark ? 0.08 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1310),
            child: Column(
              children: [
                Container(
                  color: headerBg,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _tableHeader('Task', 300, onSurface),
                      _tableHeader('Priority', 110, onSurface),
                      _tableHeader('Deadline', 145, onSurface),
                      _tableHeader('Action', 120, onSurface),
                      _tableHeader('Est. Hours', 145, onSurface),
                      _tableHeader('Status', 110, onSurface),
                      _tableHeader('Finish Window', 175, onSurface),
                      _tableHeader('Course', 205, onSurface),
                    ],
                  ),
                ),
                ...tasks.map((task) {
                  final item = planById[task.id] ??
                      planByTitle[task.title.trim().toLowerCase()];
                  return _planningTableRow(
                    context: context,
                    task: task,
                    item: item,
                    border: border,
                    onSurface: onSurface,
                    secondary: secondary,
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tableHeader(String label, double width, Color onSurface) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: TextStyle(
          color: onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _planningTableRow({
    required BuildContext context,
    required Task task,
    required StudyPlanItem? item,
    required Color border,
    required Color onSurface,
    required Color secondary,
  }) {
    final finishWindow = item == null
        ? 'Needs slot'
        : '${item.suggestedDate} ${item.suggestedTime}'.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: border))),
      child: Row(
        children: [
          SizedBox(
            width: 300,
            child: Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 110, child: _priorityPill(task.priority.name)),
          SizedBox(
            width: 145,
            child: Text(
              _deadlineLabel(task),
              style: TextStyle(
                color: task.hasRealDeadline ? secondary : AppTheme.successGreen,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 120, child: _deadlineAction(context, task)),
          SizedBox(width: 145, child: _hoursCell(context, task, secondary)),
          SizedBox(width: 110, child: _statusPill(task)),
          SizedBox(
            width: 175,
            child: Text(
              finishWindow,
              style: TextStyle(
                color: item == null ? AppTheme.warningOrange : onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 205,
            child: Text(
              task.courseName.trim().isEmpty ? 'Other' : task.courseName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: secondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Editable "expected hours to finish" cell. Tapping opens an hour picker
  /// and the customized value is sent to the AI planner on regeneration.
  Widget _hoursCell(BuildContext context, Task task, Color secondary) {
    final hours = task.estimatedMinutes / 60.0;
    final label = hours == hours.truncateToDouble()
        ? '${hours.toInt()}h'
        : '${hours.toStringAsFixed(1)}h';
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _editTaskHours(context, task),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_bottom_rounded,
                    size: 14, color: AppTheme.secondaryPurple),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.edit, size: 13, color: secondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _deadlineAction(BuildContext context, Task task) {
    final isUserDeadline = task.deadlineSource == 'user';
    if (!task.hasRealDeadline || isUserDeadline) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _pickTaskDeadline(context, task),
          icon: const Icon(Icons.event, size: 15),
          label: Text(task.hasRealDeadline ? 'Edit' : 'Set date'),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return Text(
      'Classroom',
      style: TextStyle(
        color: AppTheme.mediumGray,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _priorityPill(String priority) {
    final color = _priorityColor(priority);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.32)),
        ),
        child: Text(
          priority.toLowerCase(),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _statusPill(Task task) {
    final color = task.status == TaskStatus.missed || task.isOverdue
        ? AppTheme.errorRed
        : task.status == TaskStatus.inProgress
            ? AppTheme.secondaryPurple
            : AppTheme.primaryBlue;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          _taskStatusLabel(task),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _upcomingTaskCard(
    BuildContext context, {
    required UpGradeRem rem,
    required bool isDark,
    required String title,
    required String courseName,
    required String dueText,
    required String priority,
    required Color onSurface,
  }) {
    final priorityColor = _priorityColor(priority);
    final courseLineColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);
    final dueBg = isDark
        ? AppTheme.primaryBlue.withOpacity(0.16)
        : const Color(0xFFEFF6FF);
    final dueFg = isDark ? const Color(0xFF93C5FD) : AppTheme.primaryBlue;

    return Container(
      padding: EdgeInsets.all(rem.space(1.05)),
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  priorityColor.withOpacity(0.12),
                  const Color(0xFF111827),
                ],
              )
            : LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  priorityColor.withOpacity(0.08),
                  Colors.white,
                ],
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: priorityColor.withOpacity(isDark ? 0.35 : 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: priorityColor.withOpacity(isDark ? 0.15 : 0.1),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: rem.listTitle,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: onSurface,
                  ),
                ),
                SizedBox(height: rem.space(0.35)),
                Text(
                  courseName,
                  style: TextStyle(
                    fontSize: rem.listSubtitle,
                    color: courseLineColor,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: rem.space(0.5),
                  vertical: rem.space(0.32),
                ),
                decoration: BoxDecoration(
                  color: dueBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: dueFg.withOpacity(0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: dueFg.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  dueText,
                  style: TextStyle(
                    fontSize: rem.listSubtitle * 0.92,
                    fontWeight: FontWeight.w600,
                    color: dueFg,
                  ),
                ),
              ),
              SizedBox(width: rem.space(0.45)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: rem.space(0.5),
                  vertical: rem.space(0.32),
                ),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: priorityColor.withOpacity(0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: priorityColor.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  priority.toLowerCase(),
                  style: TextStyle(
                    fontSize: rem.listSubtitle * 0.92,
                    fontWeight: FontWeight.w700,
                    color: priorityColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── AI finish scenario: grouped day-by-day schedule ────────────────────────

  Widget _groupingToggle({
    required UpGradeRem rem,
    required bool isDark,
    required Color onSurface,
  }) {
    Widget chip(String label, _PlanGrouping value, IconData icon) {
      final selected = _grouping == value;
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _grouping = value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                gradient: selected ? AppTheme.primaryGradient : null,
                color: selected
                    ? null
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : AppTheme.primaryBlue.withOpacity(0.22),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: selected ? Colors.white : AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip('Day', _PlanGrouping.day, Icons.calendar_today_rounded),
        chip('Priority', _PlanGrouping.priority, Icons.flag_rounded),
        chip('Course', _PlanGrouping.course, Icons.menu_book_rounded),
      ],
    );
  }

  List<Widget> _buildGroupedSchedule(
    BuildContext context, {
    required UpGradeRem rem,
    required bool isDark,
    required List<StudyPlanItem> items,
    required Color onSurface,
    required Color secondary,
  }) {
    // Build ordered groups of (label, items) alongside raw date keys so each
    // day header can expose a per-day capacity editor when in day-grouping mode.
    final groups = <MapEntry<String, List<StudyPlanItem>>>[];
    // Raw ISO date keys, parallel to groups; empty string for non-day groupings.
    final groupDateKeys = <String>[];

    if (_grouping == _PlanGrouping.day) {
      final byDate = <String, List<StudyPlanItem>>{};
      for (final item in items) {
        byDate.putIfAbsent(item.suggestedDate, () => []).add(item);
      }
      final keys = byDate.keys.toList()..sort();
      for (final k in keys) {
        groups.add(MapEntry(_dayHeaderLabel(k), byDate[k]!));
        groupDateKeys.add(k);
      }
    } else if (_grouping == _PlanGrouping.priority) {
      const order = ['urgent', 'high', 'medium', 'low'];
      final byPriority = <String, List<StudyPlanItem>>{};
      for (final item in items) {
        byPriority.putIfAbsent(item.priority.toLowerCase(), () => []).add(item);
      }
      for (final p in order) {
        if (byPriority.containsKey(p)) {
          groups.add(MapEntry(
            '${p[0].toUpperCase()}${p.substring(1)} priority',
            byPriority[p]!,
          ));
          groupDateKeys.add('');
        }
      }
    } else {
      final byCourse = <String, List<StudyPlanItem>>{};
      for (final item in items) {
        final c = item.courseName.trim().isEmpty ? 'Other' : item.courseName.trim();
        byCourse.putIfAbsent(c, () => []).add(item);
      }
      final keys = byCourse.keys.toList()..sort();
      for (final k in keys) {
        groups.add(MapEntry(k, byCourse[k]!));
        groupDateKeys.add('');
      }
    }

    final widgets = <Widget>[];
    for (int i = 0; i < groups.length; i++) {
      final group = groups[i];
      final rawDateKey =
          i < groupDateKeys.length ? groupDateKeys[i] : '';
      final groupItems = group.value;
      final totalHours =
          groupItems.fold<double>(0, (sum, it) => sum + it.hoursNeeded);
      widgets.add(
        Padding(
          padding: EdgeInsets.only(
            top: rem.space(0.4),
            bottom: rem.space(0.7),
          ),
          child: _dayGroupHeader(
            rem: rem,
            isDark: isDark,
            title: group.key,
            dateKey: rawDateKey.isNotEmpty ? rawDateKey : null,
            taskCount: groupItems.length,
            totalHours: totalHours,
            onSurface: onSurface,
            secondary: secondary,
          ),
        ),
      );
      for (final item in groupItems) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(
              bottom: rem.space(0.7),
              left: rem.space(0.5),
            ),
            child: _scheduleItemCard(
              context,
              rem: rem,
              isDark: isDark,
              item: item,
              onSurface: onSurface,
              secondary: secondary,
            ),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _dayGroupHeader({
    required UpGradeRem rem,
    required bool isDark,
    required String title,
    required int taskCount,
    required double totalHours,
    required Color onSurface,
    required Color secondary,
    /// ISO date (yyyy-MM-dd) for day-grouping mode; null for priority/course mode.
    String? dateKey,
  }) {
    final hoursStr = totalHours >= 1
        ? '${totalHours.toStringAsFixed(totalHours.truncateToDouble() == totalHours ? 0 : 1)}h'
        : '${(totalHours * 60).round()}m';

    // Capacity badge: shows the student's budget for this specific day.
    final capacityForDay = dateKey != null
        ? (_dayHourOverrides[dateKey] ?? _defaultDailyHours)
        : null;
    final hasOverride =
        dateKey != null && _dayHourOverrides.containsKey(dateKey);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.event_note_rounded,
              color: Colors.white, size: 16),
        ),
        SizedBox(width: rem.space(0.55)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: rem.cardTitle,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: onSurface,
                ),
              ),
              if (dateKey != null && capacityForDay != null)
                Text(
                  hasOverride
                      ? 'Custom: ${capacityForDay.toInt()} h available'
                      : 'Budget: ${capacityForDay.toInt()} h (default)',
                  style: TextStyle(
                    fontSize: rem.listSubtitle * 0.9,
                    color: hasOverride
                        ? AppTheme.secondaryPurple
                        : secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$taskCount ${taskCount == 1 ? 'task' : 'tasks'} · $hoursStr',
            style: TextStyle(
              fontSize: rem.listSubtitle,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryBlue,
            ),
          ),
        ),
        // Per-day hours edit button — only shown in day-grouping mode.
        if (dateKey != null) ...[
          const SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                if (_isGenerating) return;
                final current =
                    _dayHourOverrides[dateKey] ?? _defaultDailyHours;
                final picked = await _pickCapacityHoursSheet(
                  title: 'Hours for ${_dayHeaderLabel(dateKey)}',
                  subtitle:
                      'How many hours can you study on this day? '
                      'This overrides the default (${_defaultDailyHours.toInt()} h).',
                  current: current,
                  allowSkip: true,
                );
                if (picked == null || !mounted) return;
                setState(() {
                  if ((picked - _defaultDailyHours).abs() < 0.01) {
                    _dayHourOverrides.remove(dateKey);
                  } else {
                    _dayHourOverrides[dateKey] = picked;
                  }
                });
                await _saveCapacity();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Day hours updated. Regenerating plan.'),
                  ),
                );
                await _generate();
              },
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Icon(
                  hasOverride
                      ? Icons.edit_calendar_rounded
                      : Icons.add_circle_outline_rounded,
                  size: 17,
                  color: hasOverride
                      ? AppTheme.secondaryPurple
                      : secondary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _scheduleItemCard(
    BuildContext context, {
    required UpGradeRem rem,
    required bool isDark,
    required StudyPlanItem item,
    required Color onSurface,
    required Color secondary,
  }) {
    final priorityColor = _priorityColor(item.priority);
    final courseName =
        item.courseName.trim().isEmpty ? '—' : item.courseName.trim();

    return Container(
      padding: EdgeInsets.all(rem.space(1.0)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: priorityColor.withOpacity(isDark ? 0.12 : 0.07),
            blurRadius: 12,
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
                width: 4,
                height: rem.cardTitle * 1.5,
                margin: const EdgeInsets.only(right: 10, top: 2),
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.taskTitle,
                      style: TextStyle(
                        fontSize: rem.listTitle,
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                      ),
                    ),
                    SizedBox(height: rem.space(0.2)),
                    Text(
                      courseName,
                      style: TextStyle(
                        fontSize: rem.listSubtitle,
                        color: secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(isDark ? 0.22 : 0.13),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: priorityColor.withOpacity(0.35)),
                ),
                child: Text(
                  item.priority.toLowerCase(),
                  style: TextStyle(
                    fontSize: rem.listSubtitle * 0.95,
                    fontWeight: FontWeight.w800,
                    color: priorityColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: rem.space(0.6)),
          Wrap(
            spacing: rem.space(0.5),
            runSpacing: rem.space(0.35),
            children: [
              if (item.suggestedTime.trim().isNotEmpty)
                _scheduleInfoChip(
                  Icons.schedule_rounded,
                  item.suggestedTime.trim(),
                  AppTheme.primaryBlue,
                  isDark,
                ),
              _scheduleInfoChip(
                Icons.hourglass_bottom_rounded,
                '${item.hoursNeeded.toStringAsFixed(item.hoursNeeded.truncateToDouble() == item.hoursNeeded ? 0 : 1)}h',
                AppTheme.secondaryPurple,
                isDark,
              ),
              if (item.deadline != null && item.deadline!.trim().isNotEmpty)
                _scheduleInfoChip(
                  Icons.flag_rounded,
                  'Due ${_shortDate(item.deadline!)}',
                  AppTheme.warningOrange,
                  isDark,
                ),
            ],
          ),
          if (item.tip.trim().isNotEmpty) ...[
            SizedBox(height: rem.space(0.6)),
            Container(
              padding: EdgeInsets.all(rem.space(0.7)),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(isDark ? 0.1 : 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 15, color: AppTheme.secondaryPurple),
                  SizedBox(width: rem.space(0.45)),
                  Expanded(
                    child: Text(
                      item.tip.trim(),
                      style: TextStyle(
                        fontSize: rem.listSubtitle,
                        color: secondary,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scheduleInfoChip(
    IconData icon,
    String label,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Turns "2026-06-18" into "Today · Thu, Jun 18" / "Tomorrow · ..." / date.
  String _dayHeaderLabel(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate.isEmpty ? 'Unscheduled' : isoDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;
    final formatted = DateFormat('EEE, MMM d').format(date);
    if (diff == 0) return 'Today · $formatted';
    if (diff == 1) return 'Tomorrow · $formatted';
    if (diff < 0) return 'Overdue window · $formatted';
    return formatted;
  }

  String _shortDate(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate;
    return DateFormat('MMM d').format(date);
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return AppTheme.errorRed;
      case 'high':
        return AppTheme.errorRed;
      case 'medium':
        return AppTheme.warningOrange;
      case 'low':
        return AppTheme.successGreen;
      default:
        return AppTheme.mediumGray;
    }
  }

  String _deadlineLabel(Task task) {
    if (!task.hasRealDeadline) return 'No deadline';
    final date = DateFormat('MMM d, h:mm a').format(task.deadline);
    if (task.status == TaskStatus.missed || task.isOverdue) {
      return '$date overdue';
    }
    return date;
  }

  String _taskStatusLabel(Task task) {
    switch (task.status) {
      case TaskStatus.completed:
        return 'Done';
      case TaskStatus.inProgress:
        return 'In progress';
      case TaskStatus.missed:
        return 'Missed';
      case TaskStatus.pending:
        return task.hasRealDeadline && task.isOverdue ? 'Missed' : 'Pending';
    }
  }

  Widget _buildAIRecommendationCard(
    BuildContext context, {
    required UpGradeRem rem,
    required bool isDark,
    required StudyPlan plan,
    required Color onSurface,
    required Color secondary,
  }) {
    return UpGradeGradientFrameCard(
      rem: rem,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(rem.space(0.75)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.secondaryPurple.withOpacity(0.25),
                      AppTheme.primaryBlue.withOpacity(0.2),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.secondaryPurple.withOpacity(0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.secondaryPurple.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: AppTheme.secondaryPurple,
                  size: rem.iconSmall * 1.15,
                ),
              ),
              SizedBox(width: rem.space(0.95)),
              Expanded(
                child: Text(
                  'AI Study Recommendation',
                  style: TextStyle(
                    fontSize: rem.sectionTitle,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                    color: onSurface,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: rem.space(0.95)),
          Text(
            plan.summary,
            style: TextStyle(
              fontSize: rem.cardBody,
              color: secondary,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: rem.space(1.1)),
          UpGradeGradientFilledButton(
            onPressed: () => setState(() => _tabIndex = 1),
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: const Text('Apply Recommendation'),
            padding: EdgeInsets.symmetric(
              horizontal: rem.space(1.35),
              vertical: rem.space(0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySection(
    BuildContext context, {
    required UpGradeRem rem,
    required bool isDark,
    required IconData icon,
    required String message,
    required Color secondary,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: rem.space(2.75)),
        child: Container(
          padding: EdgeInsets.all(rem.space(1.85)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: isDark
                ? LinearGradient(
                    colors: [
                      const Color(0xFF1E293B),
                      AppTheme.primaryBlue.withOpacity(0.08),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFEFF6FF),
                      const Color(0xFFF5F3FF),
                    ],
                  ),
            border: Border.all(
              color: AppTheme.primaryBlue.withOpacity(isDark ? 0.35 : 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(rem.space(0.85)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                  boxShadow: AppTheme.softShadow,
                ),
                child:
                    Icon(icon, size: rem.iconSmall * 1.35, color: Colors.white),
              ),
              SizedBox(height: rem.space(1.0)),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: rem.cardBody,
                  color: secondary,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading({
    required UpGradeRem rem,
    required bool isDark,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(rem.space(1.85)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(rem.space(1.35)),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: AppTheme.softShadow,
              ),
              child: SizedBox(
                width: rem.iconSmall * 1.6,
                height: rem.iconSmall * 1.6,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.25),
                ),
              ),
            ),
            SizedBox(height: rem.space(1.35)),
            Text(
              'Generating your study plan...',
              style: TextStyle(
                fontSize: rem.cardTitle,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: rem.space(0.45)),
            UpGradeMutedSubtitle(
              'AI-powered personalized schedule',
              rem: rem,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats ──────────────────────────────────────────────────────

  static _StudyPlanStats _computeStats(List<Task> tasks) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final thisWeek = tasks.where((t) {
      final d = t.deadline;
      return !d.isBefore(weekStart) && d.isBefore(weekEnd);
    }).toList();
    final hoursThisWeek =
        thisWeek.fold<int>(0, (s, t) => s + t.estimatedMinutes) / 60.0;
    final total = tasks.length;
    final completed =
        tasks.where((t) => t.status == TaskStatus.completed).length;
    final completionRate = total == 0 ? 0.0 : completed / total;

    return _StudyPlanStats(
      hoursThisWeek: hoursThisWeek,
      total: total,
      completed: completed,
      completionRate: completionRate,
    );
  }

  static List<_CourseStat> _computeCourseStats(List<Task> tasks) {
    final byCourse = <String, List<Task>>{};
    for (final t in tasks) {
      final name = t.courseName.isEmpty ? 'Other' : t.courseName;
      byCourse.putIfAbsent(name, () => []).add(t);
    }
    return byCourse.entries
        .map((e) {
          final list = e.value;
          final completed =
              list.where((t) => t.status == TaskStatus.completed).length;
          return _CourseStat(
            courseName: e.key,
            total: list.length,
            completed: completed,
          );
        })
        .where((s) => s.total > 0)
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  static List<Task> _upcomingTasks(List<Task> tasks) {
    // Include ALL actionable tasks: pending, in-progress, AND missed/overdue.
    final planning = tasks
        .where(
          (t) =>
              t.status == TaskStatus.pending ||
              t.status == TaskStatus.inProgress ||
              t.status == TaskStatus.missed,
        )
        .toList();
    planning.sort((a, b) {
      // Order strictly by deadline ascending (earliest first) so the plan is
      // chronological — this matches the backend planner and fixes ordering
      // bugs where a later deadline appeared before an earlier one. Tasks
      // without a real deadline are placed last.
      final aHas = a.hasRealDeadline;
      final bHas = b.hasRealDeadline;
      if (aHas != bHas) return aHas ? -1 : 1;
      if (!aHas && !bHas) {
        return _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
      }
      return a.deadline.compareTo(b.deadline);
    });
    return planning;
  }

  static int _priorityRank(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return 0;
      case TaskPriority.high:
        return 1;
      case TaskPriority.medium:
        return 2;
      case TaskPriority.low:
        return 3;
    }
  }
}

class _StudyPlanStats {
  final double hoursThisWeek;
  final int total;
  final int completed;
  final double completionRate;

  _StudyPlanStats({
    required this.hoursThisWeek,
    required this.total,
    required this.completed,
    required this.completionRate,
  });
}

class _CourseStat {
  final String courseName;
  final int total;
  final int completed;

  _CourseStat({
    required this.courseName,
    required this.total,
    required this.completed,
  });
}

/// How the AI finish scenario schedule is grouped in the UI.
enum _PlanGrouping { day, priority, course }
