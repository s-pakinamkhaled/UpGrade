import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/classroom_course.dart';
import '../providers/classroom_provider.dart';
import '../widgets/dashboard_secondary_shell.dart';
import '../widgets/upgrade_visual_system.dart';

/// Accent pairs for synced course tiles: [soft bg, strong accent].
const List<List<Color>> _syncedTileAccents = [
  [Color(0xFFEEF2FF), Color(0xFF4F46E5)],
  [Color(0xFFFCE7F3), Color(0xFFC026D3)],
  [Color(0xFFD1FAE5), Color(0xFF059669)],
  [Color(0xFFFEF3C7), Color(0xFFD97706)],
  [Color(0xFFE0F2FE), Color(0xFF0284C7)],
  [Color(0xFFF3E8FF), Color(0xFF7C3AED)],
];

List<Color> _accentForCourse(String id) {
  return _syncedTileAccents[id.hashCode.abs() % _syncedTileAccents.length];
}

/// Lets users add courses that are not from Google Classroom, without signing in again.
class ManualCoursesScreen extends StatefulWidget {
  /// When true, shown inside [MainNavigationScreen]'s [IndexedStack] (no back bar / secondary shell).
  final bool embeddedInShell;

  const ManualCoursesScreen({super.key, this.embeddedInShell = false});

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

    if (title.isEmpty ||
        _selectedDeadline == null ||
        _selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Enter a task name, choose a course, and pick a deadline'),
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

  Widget _buildSyncedCoursesBlock(
    BuildContext context,
    UpGradeRem t,
    bool isDark,
  ) {
    final onSurfaceMuted =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.65);
    final onSurfaceStrong =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.88);

    return Consumer<ClassroomProvider>(
      builder: (context, provider, _) {
        final synced =
            provider.courses.where((c) => !c.id.startsWith('manual_')).toList();

        return UpGradeGradientFrameCard(
          rem: t,
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(t.space(0.45)),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Icon(
                      Icons.cloud_done_rounded,
                      size: t.iconSmall * 1.25,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: t.space(0.55)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Synced from Google Classroom',
                          style: TextStyle(
                            fontSize: t.sectionTitle,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.35,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: t.space(0.35)),
                        Text(
                          synced.isEmpty
                              ? 'Sync from the Google Classroom page to see your classes here.'
                              : '${synced.length} course${synced.length == 1 ? '' : 's'} shown on My Tasks.',
                          style: TextStyle(
                            fontSize: t.cardBody,
                            height: 1.35,
                            color: onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (synced.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: t.space(0.55),
                        vertical: t.space(0.35),
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryBlue.withOpacity(0.15),
                            AppTheme.secondaryPurple.withOpacity(0.18),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppTheme.primaryBlue.withOpacity(0.25),
                        ),
                      ),
                      child: Text(
                        '${synced.length}',
                        style: TextStyle(
                          fontSize: t.listTitle,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: t.space(0.95)),
              if (synced.isEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: t.space(0.85),
                    vertical: t.space(1.0),
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF5F3FF),
                    border: Border.all(
                      color: AppTheme.secondaryPurple.withOpacity(0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: t.iconSmall * 1.2,
                        color: AppTheme.secondaryPurple,
                      ),
                      SizedBox(width: t.space(0.55)),
                      Expanded(
                        child: Text(
                          'No synced courses yet — head to Google Classroom and tap Sync.',
                          style: TextStyle(
                            fontSize: t.listSubtitle,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            color: onSurfaceStrong,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final gap = t.space(0.65);
                    int cols = 1;
                    if (w >= 900) {
                      cols = 3;
                    } else if (w >= 520) {
                      cols = 2;
                    }
                    final tileW = (w - gap * (cols - 1)) / cols;

                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: synced.map((course) {
                        final sub = (course.section?.trim().isNotEmpty ?? false)
                            ? course.section!.trim()
                            : 'Google Classroom';
                        final accent = _accentForCourse(course.id);
                        final softBg = accent[0];
                        final bold = accent[1];

                        return SizedBox(
                          width: tileW,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: t.space(0.75),
                              vertical: t.space(0.7),
                            ),
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
                                color: bold.withOpacity(isDark ? 0.35 : 0.22),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: bold.withOpacity(0.12),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: t.iconSmall * 2.35,
                                  height: t.iconSmall * 2.35,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        bold,
                                        Color.lerp(
                                              bold,
                                              AppTheme.secondaryPurple,
                                              0.35,
                                            ) ??
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
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.cast_for_education_rounded,
                                    size: t.iconSmall * 1.05,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: t.space(0.55)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        course.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: t.listTitle,
                                          fontWeight: FontWeight.w700,
                                          height: 1.2,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      SizedBox(height: t.space(0.2)),
                                      Text(
                                        sub,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: t.listSubtitle,
                                          color: onSurfaceMuted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddCourseCard(
    BuildContext context,
    UpGradeRem t,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final onSurfaceMuted = theme.colorScheme.onSurface.withOpacity(0.65);

    return UpGradeAccentStripeCard(
      rem: t,
      isDark: isDark,
      stripeGradient: const [
        AppTheme.secondaryPurple,
        AppTheme.primaryBlue,
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: t.iconSmall * 1.35,
                color: AppTheme.secondaryPurple,
              ),
              SizedBox(width: t.space(0.45)),
              Expanded(
                child: Text(
                  'Add a course',
                  style: TextStyle(
                    fontSize: t.cardTitle,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: t.space(0.45)),
          Text(
            'Courses you create here are only yours (not from Google Classroom).',
            style: TextStyle(
              fontSize: t.cardBody,
              height: 1.35,
              color: onSurfaceMuted,
            ),
          ),
          SizedBox(height: t.space(0.75)),
          TextField(
            controller: _nameController,
            style: TextStyle(fontSize: t.inputText),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(context),
            decoration: UpGradeInputDecor.themed(
              context,
              t,
              'e.g. Linear Algebra, Piano lessons',
              prefix: Icon(Icons.menu_book_outlined, size: t.iconSmall),
              fillTint: AppTheme.secondaryPurple.withOpacity(0.07),
            ),
          ),
          SizedBox(height: t.space(0.75)),
          UpGradeGradientFilledButton(
            onPressed: () => _submit(context),
            icon: Icon(Icons.add_rounded, size: t.iconSmall),
            label: Text(
              'Add course',
              style: TextStyle(
                fontSize: t.buttonLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
            padding: EdgeInsets.symmetric(vertical: t.space(0.85)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTaskCard(
    BuildContext context,
    UpGradeRem t,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final onSurfaceMuted = theme.colorScheme.onSurface.withOpacity(0.65);

    return Consumer<ClassroomProvider>(
      builder: (context, provider, _) {
        final courses = provider.courses;
        final hasCourses = courses.isNotEmpty;

        return UpGradeAccentStripeCard(
          rem: t,
          isDark: isDark,
          stripeGradient: const [
            Color(0xFF10B981),
            Color(0xFF06B6D4),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.edit_calendar_rounded,
                    size: t.iconSmall * 1.35,
                    color: const Color(0xFF0D9488),
                  ),
                  SizedBox(width: t.space(0.45)),
                  Expanded(
                    child: Text(
                      'Add a task',
                      style: TextStyle(
                        fontSize: t.cardTitle,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.space(0.45)),
              Text(
                hasCourses
                    ? 'Choose any course (yours or synced), set a due date, and it appears on My Tasks.'
                    : 'Add a course above or sync Google Classroom first — you need at least one course to attach tasks.',
                style: TextStyle(
                  fontSize: t.cardBody,
                  height: 1.35,
                  color: onSurfaceMuted,
                ),
              ),
              SizedBox(height: t.space(0.75)),
              TextField(
                controller: _taskNameController,
                style: TextStyle(fontSize: t.inputText),
                enabled: hasCourses,
                textInputAction: TextInputAction.next,
                decoration: UpGradeInputDecor.themed(
                  context,
                  t,
                  'Task name (e.g. Essay draft, Quiz prep)',
                  prefix: Icon(Icons.assignment_outlined, size: t.iconSmall),
                  fillTint: const Color(0xFF06B6D4).withOpacity(0.06),
                ),
              ),
              SizedBox(height: t.space(0.65)),
              DropdownButtonFormField<String>(
                value: _selectedCourseId != null &&
                        courses.any((c) => c.id == _selectedCourseId)
                    ? _selectedCourseId
                    : null,
                isExpanded: true,
                style: TextStyle(
                  fontSize: t.inputText,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: UpGradeInputDecor.themed(
                  context,
                  t,
                  'Select course',
                  prefix: Icon(Icons.book_outlined, size: t.iconSmall),
                  fillTint: AppTheme.primaryBlue.withOpacity(0.06),
                ),
                items: courses
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          c.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: t.inputText),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: hasCourses
                    ? (v) => setState(() => _selectedCourseId = v)
                    : null,
              ),
              SizedBox(height: t.space(0.65)),
              InkWell(
                onTap: hasCourses ? _pickDeadline : null,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: UpGradeInputDecor.themed(
                    context,
                    t,
                    'Deadline',
                    prefix:
                        Icon(Icons.calendar_today_outlined, size: t.iconSmall),
                    fillTint: AppTheme.warningOrange.withOpacity(0.07),
                  ),
                  child: Text(
                    _selectedDeadline != null
                        ? DateFormat('EEE, MMM d, y').format(_selectedDeadline!)
                        : 'Tap to pick deadline',
                    style: TextStyle(
                      fontSize: t.inputText,
                      color: _selectedDeadline != null
                          ? theme.colorScheme.onSurface
                          : onSurfaceMuted,
                    ),
                  ),
                ),
              ),
              SizedBox(height: t.space(0.85)),
              UpGradeGradientFilledButton(
                onPressed: hasCourses ? () => _addTask(context) : null,
                icon: Icon(Icons.add_task_rounded, size: t.iconSmall),
                label: Text(
                  'Add task',
                  style: TextStyle(
                    fontSize: t.buttonLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                padding: EdgeInsets.symmetric(vertical: t.space(0.85)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildManualCoursesList(
    BuildContext context,
    UpGradeRem t,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final onSurfaceMuted = theme.colorScheme.onSurface.withOpacity(0.65);
    final onSurfaceStrong = theme.colorScheme.onSurface.withOpacity(0.88);

    return Consumer<ClassroomProvider>(
      builder: (context, provider, _) {
        final manual =
            provider.courses.where((c) => c.id.startsWith('manual_')).toList();

        return UpGradeListSectionPanel(
          rem: t,
          isDark: isDark,
          tintTop: const Color(0xFFEDE9FE),
          borderAccent: AppTheme.secondaryPurple,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    color: AppTheme.secondaryPurple,
                    size: t.iconSmall * 1.25,
                  ),
                  SizedBox(width: t.space(0.45)),
                  Expanded(
                    child: Text(
                      'Your manual courses',
                      style: TextStyle(
                        fontSize: t.sectionTitle,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.space(0.55)),
              if (manual.isEmpty)
                Text(
                  'No manual courses yet. Add one in the card above or sync '
                  "${AppConstants.appName} with Google Classroom.",
                  style: TextStyle(
                    fontSize: t.cardBody,
                    height: 1.4,
                    color: onSurfaceMuted,
                  ),
                )
              else
                ...manual.map(
                  (c) => Padding(
                    padding: EdgeInsets.only(bottom: t.space(0.5)),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: t.space(0.85),
                          vertical: t.space(0.15),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tileColor: isDark
                            ? const Color(0xFF1E293B)
                            : AppTheme.primaryBlue.withOpacity(0.06),
                        leading: Icon(
                          Icons.menu_book_outlined,
                          size: t.iconSmall * 1.2,
                          color: AppTheme.primaryBlue.withOpacity(0.9),
                        ),
                        title: Text(
                          c.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: t.listTitle,
                            color: onSurfaceStrong,
                          ),
                        ),
                        subtitle: Text(
                          'Not from Classroom',
                          style: TextStyle(fontSize: t.listSubtitle),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: t.iconSmall * 1.15,
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
                                  .removeManualCourse(c.id);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildManualTasksList(
    BuildContext context,
    UpGradeRem t,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final onSurfaceMuted = theme.colorScheme.onSurface.withOpacity(0.65);
    final onSurfaceStrong = theme.colorScheme.onSurface.withOpacity(0.88);

    return Consumer<ClassroomProvider>(
      builder: (context, provider, _) {
        final manualTasks =
            provider.tasks.where((t) => t.id.startsWith('manual_')).toList()
              ..sort(
                (a, b) => a.deadline.compareTo(b.deadline),
              );

        return UpGradeListSectionPanel(
          rem: t,
          isDark: isDark,
          tintTop: const Color(0xFFFFF7ED),
          borderAccent: AppTheme.warningOrange,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.task_alt_rounded,
                    color: AppTheme.warningOrange,
                    size: t.iconSmall * 1.25,
                  ),
                  SizedBox(width: t.space(0.45)),
                  Expanded(
                    child: Text(
                      'Tasks you added',
                      style: TextStyle(
                        fontSize: t.sectionTitle,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.space(0.55)),
              if (manualTasks.isEmpty)
                Text(
                  'No manual tasks yet. Use “Add a task” above — they show up on My Tasks.',
                  style: TextStyle(
                    fontSize: t.cardBody,
                    height: 1.4,
                    color: onSurfaceMuted,
                  ),
                )
              else
                ...manualTasks.map(
                  (task) => Padding(
                    padding: EdgeInsets.only(bottom: t.space(0.5)),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: t.space(0.85),
                          vertical: t.space(0.15),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tileColor: isDark
                            ? const Color(0xFF1E293B)
                            : AppTheme.warningOrange.withOpacity(0.08),
                        leading: Icon(
                          Icons.event_outlined,
                          size: t.iconSmall * 1.2,
                          color: AppTheme.warningOrange.withOpacity(0.95),
                        ),
                        title: Text(
                          task.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: t.listTitle,
                            color: onSurfaceStrong,
                          ),
                        ),
                        subtitle: Text(
                          '${task.courseName} · Due ${DateFormat('MMM d, y').format(task.deadline)}',
                          style: TextStyle(fontSize: t.listSubtitle),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: t.iconSmall * 1.15,
                            color: AppTheme.errorRed.withOpacity(0.85),
                          ),
                          tooltip: 'Remove task',
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Remove task?'),
                                content: Text('Remove "${task.title}"?'),
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
                                  .removeManualTask(task.id);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final t = UpGradeRem(width);
        final side = t.space(1.15);

        return Container(
          decoration: UpGradePageDecor.pageBackground(isDark),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(side),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UpGradeGradientTitle('My courses', rem: t, isDark: isDark),
                SizedBox(height: t.space(0.35)),
                UpGradeMutedSubtitle(_subtitle, rem: t, isDark: isDark),
                SizedBox(height: t.space(1.2)),
                _buildSyncedCoursesBlock(context, t, isDark),
                SizedBox(height: t.space(0.85)),
                _buildAddCourseCard(context, t, isDark),
                SizedBox(height: t.space(0.85)),
                _buildAddTaskCard(context, t, isDark),
                SizedBox(height: t.space(1.1)),
                _buildManualCoursesList(context, t, isDark),
                SizedBox(height: t.space(1.1)),
                _buildManualTasksList(context, t, isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _buildPage(context);
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
}
