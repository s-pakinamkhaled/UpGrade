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

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

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
  StudyPlan? _plan;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _plan = null;
    });

    try {
      final provider = context.read<ClassroomProvider>();
      final allTasks = provider.tasks;
      final activeTasks = allTasks
          .where((t) =>
              t.status == TaskStatus.pending ||
              t.status == TaskStatus.inProgress)
          .toList();

      final user = FirebaseAuth.instance.currentUser;
      final studentName =
          user?.displayName ?? user?.email?.split('@').first ?? 'Student';

      final response = await ApiService().generateStudyPlan(
        studentName: studentName,
        tasks: activeTasks,
      );

      if (!mounted) return;

      if (response != null) {
        setState(() {
          _plan = StudyPlan.fromJson(response);
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
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
              final tasks = provider.tasks;
              final stats = _computeStats(tasks);
              final courseStats = _computeCourseStats(tasks);
              final upcomingTasks = _upcomingTasks(tasks);

              if (_loading && _plan == null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: _buildLoading(rem: rem, isDark: isDark),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, isDark, rem),
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
          onPressed: _loading ? null : _generate,
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Create New Plan'),
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
    final hoursStr =
        hoursThisWeek >= 1
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
                    color: AppTheme.primaryBlue.withOpacity(isDark ? 0.5 : 0.28),
                  )
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withOpacity(isDark ? 0.2 : 0.1),
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
    final hoursPerWeek = (course.total * 30 / 60).ceil(); // rough: 30 min per task

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
                icon: Icon(Icons.edit_outlined, size: rem.iconSmall, color: secondary),
                tooltip: 'Edit',
              ),
            ],
          ),
          SizedBox(height: rem.space(1.0)),
          Row(
            children: [
              Icon(Icons.schedule, size: rem.listSubtitle * 1.1, color: secondary),
              SizedBox(width: rem.space(0.35)),
              Text(
                '${hoursPerWeek}h/week',
                style: TextStyle(fontSize: rem.listSubtitle, color: secondary, fontWeight: FontWeight.w500),
              ),
              SizedBox(width: rem.space(1.15)),
              Icon(Icons.flag, size: rem.listSubtitle * 1.1, color: secondary),
              SizedBox(width: rem.space(0.35)),
              Text(
                '${(progress * 100).toInt()}% complete',
                style: TextStyle(fontSize: rem.listSubtitle, color: secondary, fontWeight: FontWeight.w500),
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
        isDark ? AppTheme.primaryBlue.withOpacity(0.18) : const Color(0xFFEFF6FF),
      ),
      (
        AppTheme.secondaryPurple,
        isDark ? AppTheme.secondaryPurple.withOpacity(0.18) : const Color(0xFFF5F3FF),
      ),
      (
        AppTheme.successGreen,
        isDark ? AppTheme.successGreen.withOpacity(0.18) : const Color(0xFFECFDF5),
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
    return name.length >= 6 ? name.substring(0, 6).toUpperCase() : name.toUpperCase();
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
    final usePlan = items.isNotEmpty;

    if (!usePlan && fallbackTasks.isEmpty) {
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
        _sectionTitle('Upcoming Tasks', rem, onSurface),
        SizedBox(height: rem.space(1.0)),
        if (usePlan)
          ...items.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: rem.space(0.75)),
              child: _upcomingTaskCard(
                context,
                rem: rem,
                isDark: isDark,
                title: item.taskTitle,
                courseName: item.courseName.trim().isNotEmpty
                    ? item.courseName.trim()
                    : '—',
                dueText: 'Due ${item.suggestedDate}',
                priority: item.priority,
                onSurface: onSurface,
              ),
            ),
          )
        else
          ...fallbackTasks.take(10).map(
            (task) {
              final days = task.deadline.difference(DateTime.now()).inDays;
              final dueText =
                  days < 0
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
    final courseLineColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF334155);
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
                child: Icon(icon, size: rem.iconSmall * 1.35, color: Colors.white),
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
    return byCourse.entries.map((e) {
      final list = e.value;
      final completed =
          list.where((t) => t.status == TaskStatus.completed).length;
      return _CourseStat(
        courseName: e.key,
        total: list.length,
        completed: completed,
      );
    }).where((s) => s.total > 0).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  static List<Task> _upcomingTasks(List<Task> tasks) {
    final now = DateTime.now();
    final pending = tasks
        .where((t) =>
            (t.status == TaskStatus.pending || t.status == TaskStatus.inProgress) &&
            !t.deadline.isBefore(now))
        .toList();
    pending.sort((a, b) => a.deadline.compareTo(b.deadline));
    return pending.take(15).toList();
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
