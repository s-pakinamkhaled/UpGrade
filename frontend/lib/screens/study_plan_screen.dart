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
// Daily Planner screen → tap the "Generate AI Plan" button
// → Navigator.pushNamed(context, AppConstants.routeStudyPlan)
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
// _loading=true  → shows spinner + "Llama 3.3 is analysing your tasks..."
// _error≠null    → shows error message + retry button
// _plan≠null     → shows full plan UI
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/task.dart';
import '../models/study_plan.dart';
import '../providers/classroom_provider.dart';
import '../services/api_service.dart';
import '../widgets/dashboard_secondary_shell.dart';

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
  String? _error;
  StudyPlan? _plan;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
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
          _error = 'Failed to generate plan. Check your backend connection.';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF8FAFC);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final secondary = isDark ? const Color(0xFF9CA3AF) : AppTheme.mediumGray;

    Widget planContent() {
      return Consumer<ClassroomProvider>(
        builder: (context, provider, _) {
          final tasks = provider.tasks;
          final stats = _computeStats(tasks);
          final courseStats = _computeCourseStats(tasks);
          final upcomingTasks = _upcomingTasks(tasks);

          if (_loading && _plan == null && _error == null) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: _buildLoading(),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, onSurface, secondary),
              const SizedBox(height: 28),
              _buildSummaryCards(
                context,
                stats: stats,
                courseCount: courseStats.length,
                surface: surface,
                onSurface: onSurface,
                secondary: secondary,
              ),
              const SizedBox(height: 24),
              _buildTabBar(context, surface, onSurface, secondary),
              const SizedBox(height: 20),
              if (_tabIndex == 0)
                _buildMyCourses(
                  context,
                  courseStats: courseStats,
                  surface: surface,
                  onSurface: onSurface,
                  secondary: secondary,
                )
              else
                _buildUpcomingTasks(
                  context,
                  plan: _plan,
                  fallbackTasks: upcomingTasks,
                  surface: surface,
                  onSurface: onSurface,
                  secondary: secondary,
                ),
              if (_plan != null && _plan!.summary.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildAIRecommendationCard(
                  context,
                  plan: _plan!,
                  onSurface: onSurface,
                  secondary: secondary,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 24),
                _buildErrorBanner(context),
              ],
              const SizedBox(height: 32),
            ],
          );
        },
      );
    }

    final narrow = Scaffold(
      backgroundColor: bg,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: planContent(),
      ),
    );

    return DashboardSecondaryShell(
      highlightRoute: AppConstants.routeStudyPlan,
      narrow: narrow,
      wideBody: ColoredBox(
        color: bg,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: planContent(),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color onSurface,
    Color secondary,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        final titleSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Study Plan',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'AI-powered personalized study schedule',
              style: TextStyle(
                fontSize: 14,
                color: secondary,
              ),
            ),
          ],
        );
        final button = FilledButton.icon(
          onPressed: _loading ? null : _generate,
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Create New Plan'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: AppTheme.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleSection,
              const SizedBox(height: 16),
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
    required _StudyPlanStats stats,
    required int courseCount,
    required Color surface,
    required Color onSurface,
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
                icon: Icons.calendar_today,
                iconBg: AppTheme.primaryBlue.withOpacity(0.12),
                iconColor: AppTheme.primaryBlue,
                label: 'This Week',
                value: hoursStr,
                surface: surface,
                onSurface: onSurface,
                secondary: secondary,
              ),
              const SizedBox(height: 12),
              _statCard(
                context,
                icon: Icons.menu_book,
                iconBg: AppTheme.secondaryPurple.withOpacity(0.12),
                iconColor: AppTheme.secondaryPurple,
                label: 'Active Courses',
                value: '$courseCount',
                surface: surface,
                onSurface: onSurface,
                secondary: secondary,
              ),
              const SizedBox(height: 12),
              _statCard(
                context,
                icon: Icons.flag,
                iconBg: AppTheme.successGreen.withOpacity(0.12),
                iconColor: AppTheme.successGreen,
                label: 'Completion',
                value: completionStr,
                surface: surface,
                onSurface: onSurface,
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
            icon: Icons.calendar_today,
            iconBg: AppTheme.primaryBlue.withOpacity(0.12),
            iconColor: AppTheme.primaryBlue,
            label: 'This Week',
            value: hoursStr,
            surface: surface,
            onSurface: onSurface,
            secondary: secondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _statCard(
            context,
            icon: Icons.menu_book,
            iconBg: AppTheme.secondaryPurple.withOpacity(0.12),
            iconColor: AppTheme.secondaryPurple,
            label: 'Active Courses',
            value: '$courseCount',
            surface: surface,
            onSurface: onSurface,
            secondary: secondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _statCard(
            context,
            icon: Icons.flag,
            iconBg: AppTheme.successGreen.withOpacity(0.12),
            iconColor: AppTheme.successGreen,
            label: 'Completion',
            value: completionStr,
            surface: surface,
            onSurface: onSurface,
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
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
    required Color surface,
    required Color onSurface,
    required Color secondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: secondary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: onSurface,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(
    BuildContext context,
    Color surface,
    Color onSurface,
    Color secondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: secondary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabChip(
              label: 'My Courses',
              selected: _tabIndex == 0,
              onTap: () => setState(() => _tabIndex = 0),
              surface: surface,
              onSurface: onSurface,
            ),
          ),
          Expanded(
            child: _tabChip(
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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyCourses(
    BuildContext context, {
    required List<_CourseStat> courseStats,
    required Color surface,
    required Color onSurface,
    required Color secondary,
  }) {
    if (courseStats.isEmpty) {
      return _emptySection(
        context,
        icon: Icons.menu_book,
        message: 'No courses yet. Sync Google Classroom or add tasks.',
        secondary: secondary,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Courses',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 16),
        ...courseStats.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _courseCard(
              context,
              course: c,
              surface: surface,
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
    required _CourseStat course,
    required Color surface,
    required Color onSurface,
    required Color secondary,
  }) {
    final progress = course.total == 0 ? 0.0 : course.completed / course.total;
    final code = _courseCode(course.courseName);
    final hoursPerWeek = (course.total * 30 / 60).ceil(); // rough: 30 min per task

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: secondary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        code,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.edit_outlined, size: 20, color: secondary),
                tooltip: 'Edit',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: secondary),
              const SizedBox(width: 6),
              Text(
                '${hoursPerWeek}h/week',
                style: TextStyle(fontSize: 13, color: secondary),
              ),
              const SizedBox(width: 20),
              Icon(Icons.flag, size: 16, color: secondary),
              const SizedBox(width: 6),
              Text(
                '${(progress * 100).toInt()}% complete',
                style: TextStyle(fontSize: 13, color: secondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = progress.clamp(0.0, 1.0) * constraints.maxWidth;
                  return Stack(
                    children: [
                      Container(
                        width: constraints.maxWidth,
                        color: secondary.withOpacity(0.2),
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
          const SizedBox(height: 12),
          Row(
            children: [
              _scheduleChip('Mon 9-11 AM', secondary),
              const SizedBox(width: 8),
              _scheduleChip('Wed 2-4 PM', secondary),
              const SizedBox(width: 8),
              _scheduleChip('Fri 10-12 PM', secondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scheduleChip(String label, Color secondary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: secondary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: secondary),
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
    StudyPlan? plan,
    required List<Task> fallbackTasks,
    required Color surface,
    required Color onSurface,
    required Color secondary,
  }) {
    final items = plan?.items ?? [];
    final usePlan = items.isNotEmpty;

    if (!usePlan && fallbackTasks.isEmpty) {
      return _emptySection(
        context,
        icon: Icons.assignment_outlined,
        message: 'No upcoming tasks. Create a plan or add assignments.',
        secondary: secondary,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming Tasks',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 16),
        if (usePlan)
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _upcomingTaskCard(
                context,
                title: item.taskTitle,
                courseCode: item.courseName.isNotEmpty
                    ? _courseCode(item.courseName)
                    : '—',
                dueText: 'Due ${item.suggestedDate}',
                priority: item.priority,
                surface: surface,
                onSurface: onSurface,
                secondary: secondary,
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
                padding: const EdgeInsets.only(bottom: 12),
                child: _upcomingTaskCard(
                  context,
                  title: task.title,
                  courseCode: _courseCode(task.courseName),
                  dueText: dueText,
                  priority: task.priority.name,
                  surface: surface,
                  onSurface: onSurface,
                  secondary: secondary,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _upcomingTaskCard(
    BuildContext context, {
    required String title,
    required String courseCode,
    required String dueText,
    required String priority,
    required Color surface,
    required Color onSurface,
    required Color secondary,
  }) {
    final priorityColor = _priorityColor(priority);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: secondary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  courseCode,
                  style: TextStyle(fontSize: 13, color: secondary),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dueText,
                  style: TextStyle(fontSize: 12, color: secondary),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  priority.toLowerCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
    required StudyPlan plan,
    required Color onSurface,
    required Color secondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.secondaryPurple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.secondaryPurple.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryPurple.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: AppTheme.secondaryPurple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'AI Study Recommendation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            plan.summary,
            style: TextStyle(
              fontSize: 14,
              color: secondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.softShadow,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _tabIndex = 1),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle_outline,
                          color: AppTheme.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Apply Recommendation',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySection(
    BuildContext context, {
    required IconData icon,
    required String message,
    required Color secondary,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(icon, size: 48, color: secondary.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: secondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.softGradient,
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            const Text(
              'Generating your study plan...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'AI-powered personalized schedule',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.darkText.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.errorRed, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(fontSize: 14, color: AppTheme.darkText),
            ),
          ),
          TextButton(
            onPressed: _generate,
            child: const Text('Retry'),
          ),
        ],
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
