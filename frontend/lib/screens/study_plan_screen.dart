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

import '../core/theme.dart';
import '../models/task.dart';
import '../models/study_plan.dart';
import '../providers/classroom_provider.dart';
import '../services/api_service.dart';

class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({super.key});

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
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

      // Filter to active (pending + inProgress) tasks only
      final activeTasks = allTasks
          .where((t) =>
              t.status == TaskStatus.pending ||
              t.status == TaskStatus.inProgress)
          .toList();

      // Get student name from Firebase Auth
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: AppTheme.softShadow,
              ),
              child: const Icon(Icons.auto_awesome, color: AppTheme.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'AI Study Plan',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _generate,
            icon: const Icon(Icons.refresh),
            tooltip: 'Regenerate',
          ),
        ],
      ),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _plan != null
                  ? _buildPlan()
                  : _buildError(),
    );
  }

  // ── Loading ───────────────────────────────────────────────────

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
              'Llama 3.3 is analysing your tasks...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generating a personalised study plan',
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

  // ── Error ─────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed.withOpacity(0.7)),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.darkText.withOpacity(0.8)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Plan UI ───────────────────────────────────────────────────

  Widget _buildPlan() {
    final plan = _plan!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSummaryCard(plan),
          const SizedBox(height: 16),
          ...plan.items.map(_buildPlanItemCard),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(StudyPlan plan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school, color: AppTheme.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Study Plan for ${plan.studentName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Generated at ${_formatTimestamp(plan.generatedAt)}',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.white.withOpacity(0.8),
            ),
          ),
          if (plan.summary.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              plan.summary,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.white.withOpacity(0.95),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanItemCard(StudyPlanItem item) {
    final priorityColor = _priorityColor(item.priority);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.softShadow,
        border: Border(
          left: BorderSide(color: priorityColor, width: 4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row + priority badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.taskTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _priorityBadge(item.priority, priorityColor),
              ],
            ),

            // Course name
            if (item.courseName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.courseName,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.darkText.withOpacity(0.6),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Info chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(Icons.calendar_today, item.suggestedDate),
                _infoChip(Icons.access_time, item.suggestedTime),
                _infoChip(Icons.hourglass_bottom,
                    '${item.hoursNeeded.toStringAsFixed(1)} hrs'),
              ],
            ),

            // Tip
            if (item.tip.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 18, color: AppTheme.warningOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.tip,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.darkText.withOpacity(0.8),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryBlue),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priorityBadge(String priority, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return AppTheme.errorRed;
      case 'high':
        return AppTheme.warningOrange;
      case 'medium':
        return AppTheme.primaryBlue;
      case 'low':
        return AppTheme.successGreen;
      default:
        return AppTheme.mediumGray;
    }
  }

  String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month}/${dt.year} $h:$m';
    } catch (_) {
      return iso;
    }
  }
}
