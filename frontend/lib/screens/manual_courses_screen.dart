import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/classroom_course.dart';
import '../providers/classroom_provider.dart';
import '../widgets/dashboard_shell_row.dart';
import '../widgets/gradient_card.dart';
import '../widgets/upgrade_page_shell.dart';

/// Lets users add courses that are not from Google Classroom, without signing in again.
class ManualCoursesScreen extends StatefulWidget {
  const ManualCoursesScreen({super.key});

  @override
  State<ManualCoursesScreen> createState() => _ManualCoursesScreenState();
}

class _ManualCoursesScreenState extends State<ManualCoursesScreen> {
  final _nameController = TextEditingController();
  final _taskNameController = TextEditingController();
  String? _selectedCourseId;
  DateTime? _selectedDeadline;

  static const String _subtitle =
      'Add your own courses and tasks with deadlines — same idea as onboarding. '
      'Pick any course (manual or synced from Classroom). Everything stays saved after login.';

  @override
  void dispose() {
    _nameController.dispose();
    _taskNameController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _selectedDeadline = picked);
    }
  }

  Future<void> _addTask(BuildContext context) async {
    final title = _taskNameController.text.trim();
    final provider = context.read<ClassroomProvider>();
    final courses = provider.courses;

    if (title.isEmpty || _selectedDeadline == null || _selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a task name, choose a course, and pick a deadline'),
        ),
      );
      return;
    }

    ClassroomCourse? course;
    for (final c in courses) {
      if (c.id == _selectedCourseId) {
        course = c;
        break;
      }
    }
    if (course == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected course is no longer available')),
      );
      return;
    }

    await provider.addManualTask(
      title: title,
      deadline: _selectedDeadline!,
      courseId: course.id,
      courseName: course.name,
    );

    if (!context.mounted) return;
    _taskNameController.clear();
    setState(() {
      _selectedDeadline = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added task for "${course.name}"')),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a course name')),
      );
      return;
    }
    await context.read<ClassroomProvider>().addManualCourse(name);
    if (!context.mounted) return;
    _nameController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "$name"')),
    );
  }

  InputDecoration _fieldDecoration(String hint, {Widget? prefix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefix,
      filled: true,
      fillColor: AppTheme.primaryBlue.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    );
  }

  Widget _buildCoursesColumn(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceMuted = theme.colorScheme.onSurface.withOpacity(0.65);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GradientCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add a course',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Courses you create here are only yours (not from Google Classroom).',
                style: TextStyle(fontSize: 12, color: onSurfaceMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(context),
                decoration: _fieldDecoration('e.g. Linear Algebra, Piano lessons',
                    prefix: const Icon(Icons.menu_book_outlined)),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _submit(context),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add course'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Consumer<ClassroomProvider>(
          builder: (context, provider, _) {
            final courses = provider.courses;
            final hasCourses = courses.isNotEmpty;

            return GradientCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Add a task',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasCourses
                        ? 'Choose any course (yours or synced), set a due date, and it appears in your planner.'
                        : 'Add a course above or sync Google Classroom first — you need at least one course to attach tasks.',
                    style: TextStyle(fontSize: 12, color: onSurfaceMuted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _taskNameController,
                    enabled: hasCourses,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      'Task name (e.g. Essay draft, Quiz prep)',
                      prefix: const Icon(Icons.assignment_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCourseId != null &&
                            courses.any((c) => c.id == _selectedCourseId)
                        ? _selectedCourseId
                        : null,
                    decoration: _fieldDecoration(
                      'Select course',
                      prefix: const Icon(Icons.book_outlined),
                    ),
                    items: courses
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: hasCourses
                        ? (v) => setState(() => _selectedCourseId = v)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: hasCourses ? _pickDeadline : null,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: _fieldDecoration(
                        'Deadline',
                        prefix: const Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(
                        _selectedDeadline != null
                            ? DateFormat('EEE, MMM d, y')
                                .format(_selectedDeadline!)
                            : 'Tap to pick deadline',
                        style: TextStyle(
                          color: _selectedDeadline != null
                              ? theme.colorScheme.onSurface
                              : onSurfaceMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: hasCourses ? () => _addTask(context) : null,
                    icon: const Icon(Icons.add_task, size: 20),
                    label: const Text('Add task'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Consumer<ClassroomProvider>(
          builder: (context, provider, _) {
            final manual = provider.courses
                .where((c) => c.id.startsWith('manual_'))
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your manual courses',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 10),
                if (manual.isEmpty)
                  Text(
                    'No manual courses yet. Add one in the first card or sync '
                    "${AppConstants.appName} with Google Classroom.",
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.darkText.withOpacity(0.65),
                    ),
                  )
                else
                  ...manual.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor: AppTheme.primaryBlue.withOpacity(0.06),
                          leading: Icon(
                            Icons.menu_book_outlined,
                            color: AppTheme.primaryBlue.withOpacity(0.9),
                          ),
                          title: Text(
                            c.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text('Not from Classroom'),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: AppTheme.errorRed.withOpacity(0.85),
                            ),
                            tooltip: 'Remove course',
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Remove course?'),
                                  content: Text(
                                    'Remove "${c.name}" and any tasks linked to it?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true && context.mounted) {
                                await context
                                    .read<ClassroomProvider>()
                                    .removeManualCourse(c.id);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Consumer<ClassroomProvider>(
          builder: (context, provider, _) {
            final manualTasks = provider.tasks
                .where((t) => t.id.startsWith('manual_'))
                .toList()
              ..sort(
                (a, b) => a.deadline.compareTo(b.deadline),
              );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tasks you added',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 10),
                if (manualTasks.isEmpty)
                  Text(
                    'No manual tasks yet. Use “Add a task” above — they show up in your daily planner.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.darkText.withOpacity(0.65),
                    ),
                  )
                else
                  ...manualTasks.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor: AppTheme.warningOrange.withOpacity(0.08),
                          leading: Icon(
                            Icons.event_outlined,
                            color: AppTheme.warningOrange.withOpacity(0.95),
                          ),
                          title: Text(
                            t.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${t.courseName} · Due ${DateFormat('MMM d, y').format(t.deadline)}',
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: AppTheme.errorRed.withOpacity(0.85),
                            ),
                            tooltip: 'Remove task',
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Remove task?'),
                                  content: Text('Remove "${t.title}"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true && context.mounted) {
                                await context
                                    .read<ClassroomProvider>()
                                    .removeManualTask(t.id);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;

    if (wide) {
      final theme = Theme.of(context);
      return Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainerHighest
            .withOpacity(theme.brightness == Brightness.dark ? 0.35 : 1),
        body: DashboardShellRow(
          popOverlayRouteAfterSidebarAction: true,
          highlightRoute: AppConstants.routeManualCourses,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 640,
                        minHeight: constraints.maxHeight - 32,
                      ),
                      child: Material(
                        color: theme.colorScheme.surface,
                        elevation: 2,
                        shadowColor: Colors.black26,
                        borderRadius: BorderRadius.circular(28),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 28,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'My courses',
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
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.72),
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildCoursesColumn(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    return UpGradePageShell(
      title: 'My courses',
      subtitle: _subtitle,
      child: _buildCoursesColumn(context),
    );
  }
}
