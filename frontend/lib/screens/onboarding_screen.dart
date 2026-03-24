import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/classroom_provider.dart';
import '../models/classroom_course.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;

  // Step 1: Courses
  final TextEditingController _courseController = TextEditingController();
  final List<String> _manualCourses = [];

  // Step 2: Deadlines/Tasks
  final TextEditingController _taskNameController = TextEditingController();
  DateTime? _selectedDeadline;
  String? _selectedCourseId;
  final List<_ManualTask> _manualTasks = [];

  // Step 3: Preferred times
  final List<String> _preferredTimes = [];

  @override
  void initState() {
    super.initState();
    // Clear any SnackBar from previous screen (e.g. sync or pairing) so UI is clean
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    });
  }

  @override
  void dispose() {
    _courseController.dispose();
    _taskNameController.dispose();
    super.dispose();
  }

  void _addCourse() {
    final name = _courseController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _manualCourses.add(name);
      _courseController.clear();
    });
  }

  void _removeCourse(int index) {
    setState(() {
      _manualCourses.removeAt(index);
    });
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDeadline = picked);
    }
  }

  void _addTask() {
    final name = _taskNameController.text.trim();
    if (name.isEmpty || _selectedDeadline == null || _selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in task name, deadline, and select a course')),
      );
      return;
    }
    setState(() {
      _manualTasks.add(_ManualTask(
        name: name,
        deadline: _selectedDeadline!,
        courseId: _selectedCourseId!,
        courseName: _allCourses.firstWhere((c) => c.id == _selectedCourseId).name,
      ));
      _taskNameController.clear();
      _selectedDeadline = null;
      _selectedCourseId = null;
    });
  }

  void _removeTask(int index) {
    setState(() {
      _manualTasks.removeAt(index);
    });
  }

  List<ClassroomCourse> get _allCourses {
    final provider = context.read<ClassroomProvider>();
    final syncedCourses = provider.courses;
    final manual = _manualCourses
        .asMap()
        .entries
        .map((e) => ClassroomCourse(id: 'manual_onboarding_${e.key}', name: e.value))
        .toList();
    return [...syncedCourses, ...manual];
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    final provider = context.read<ClassroomProvider>();

    // Save manual courses
    for (final name in _manualCourses) {
      await provider.addManualCourse(name);
    }

    // Save manual tasks
    for (final t in _manualTasks) {
      // Find the actual course (may be synced or manual)
      final courses = provider.courses;
      final match = courses.where((c) => c.name == t.courseName).toList();
      final courseId = match.isNotEmpty ? match.first.id : t.courseId;
      await provider.addManualTask(
        title: t.name,
        deadline: t.deadline,
        courseId: courseId,
        courseName: t.courseName,
      );
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppConstants.routeHome);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final stepMeta = [
      {
        'icon': Icons.school_outlined,
        'title': 'Smart Study Planning',
        'subtitle': 'AI-powered schedules that adapt to your workload, deadlines, and study habits.',
      },
      {
        'icon': Icons.assignment_outlined,
        'title': 'Set Your Deadlines',
        'subtitle': 'Add tasks with due dates so UpGrade can plan your day precisely.',
      },
      {
        'icon': Icons.access_time_outlined,
        'title': 'Choose Preferred Times',
        'subtitle': 'Tell UpGrade when you study best to build the right focus sessions.',
      },
    ];

    final meta = stepMeta[_currentStep];
    final stepNumber = _currentStep + 1;
    const stepTotal = 3;

    final bgGradient = LinearGradient(
      colors: isDark
          ? [
              AppTheme.primaryBlue.withOpacity(0.22),
              AppTheme.secondaryPurple.withOpacity(0.22),
            ]
          : [AppTheme.primaryBlue, AppTheme.secondaryPurple],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? theme.colorScheme.onSurface : Colors.white,
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        // Top header (progress + icon + title/subtitle)
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? theme.colorScheme.surface.withOpacity(0.55)
                                : Colors.white.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            children: [
                              // Progress Indicator (3 steps)
                              Row(
                                children: List.generate(3, (index) {
                                  final done = index <= _currentStep;
                                  return Expanded(
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      height: 6,
                                      margin:
                                          EdgeInsets.only(right: index < 2 ? 10 : 0),
                                      decoration: BoxDecoration(
                                        gradient: done ? AppTheme.primaryGradient : null,
                                        color: done
                                            ? null
                                            : theme.colorScheme.onSurface.withOpacity(
                                                isDark ? 0.12 : 0.28),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow:
                                            done ? AppTheme.softShadow : null,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 18),

                              // Step Icon
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: AppTheme.mediumShadow,
                                ),
                                child: Icon(
                                  meta['icon'] as IconData,
                                  size: 28,
                                  color: AppTheme.white,
                                ),
                              ),
                              const SizedBox(height: 12),

                              Text(
                                meta['title'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                meta['subtitle'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                  height: 1.4,
                                ),
                              ),

                              const SizedBox(height: 14),
                              // Premium bullets (subtle)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 18,
                                      color: AppTheme.successGreen),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Adaptive & personalized',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Card (step content)
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? theme.colorScheme.surface
                                  : Colors.white.withOpacity(0.96),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: AppTheme.mediumShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 320),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    transitionBuilder:
                                        (Widget child, Animation<double> animation) {
                                      final curved = CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOutCubic,
                                      );
                                      return FadeTransition(
                                        opacity: curved,
                                        child: ScaleTransition(
                                          scale: Tween<double>(begin: 0.98, end: 1)
                                              .animate(curved),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: KeyedSubtree(
                                      key: ValueKey<int>(_currentStep),
                                      child: _currentStep == 0
                                          ? _buildCoursesStep()
                                          : _currentStep == 1
                                              ? _buildDeadlinesStep()
                                              : _buildStudyTimesStep(),
                                    ),
                                  ),
                                ),

                                // Footer navigation
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          if (_currentStep > 0)
                                            TextButton.icon(
                                              onPressed: () {
                                                setState(() => _currentStep--);
                                              },
                                              icon: const Icon(Icons.arrow_back),
                                              label: const Text('Back'),
                                            )
                                          else
                                            const SizedBox(width: 72),
                                          Expanded(
                                            child: Center(
                                              child: TextButton(
                                                onPressed: _finishOnboarding,
                                                child: const Text('Skip'),
                                              ),
                                            ),
                                          ),
                                          _buildGradientNextButton(
                                            onPressed: _nextStep,
                                            label: _currentStep < 2
                                                ? 'Next'
                                                : 'Get Started',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Step $stepNumber of $stepTotal',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientNextButton({
    required VoidCallback onPressed,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.mediumShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, color: AppTheme.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== STEP 1: COURSES ====================
  Widget _buildCoursesStep() {
    final syncedCourses = context.watch<ClassroomProvider>().courses;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _courseController,
                  decoration: const InputDecoration(
                    hintText: 'Course name (e.g., CS 101)',
                    prefixIcon: Icon(Icons.book),
                  ),
                  onSubmitted: (_) => _addCourse(),
                ),
              ),
              const SizedBox(width: 8),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: IconButton(
                  onPressed: _addCourse,
                  icon: const Icon(Icons.add_circle),
                  color: AppTheme.primaryBlue,
                  iconSize: 36,
                  tooltip: 'Add course',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (syncedCourses.isNotEmpty) ...[
            Text(
              'Synced from Google Classroom:',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.mediumGray),
            ),
            const SizedBox(height: 8),
            ...syncedCourses.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.cloud_done, color: AppTheme.successGreen),
                    title: Text(c.name),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_manualCourses.isNotEmpty) ...[
            Text(
              'Manual courses:',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.mediumGray),
            ),
            const SizedBox(height: 8),
            ..._manualCourses.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.book, color: AppTheme.primaryBlue),
                        title: Text(e.value),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _removeCourse(e.key),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ==================== STEP 2: DEADLINES ====================
  Widget _buildDeadlinesStep() {
    final courses = _allCourses;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          TextField(
            controller: _taskNameController,
            decoration: const InputDecoration(
              hintText: 'Task name (e.g., Essay draft)',
              prefixIcon: Icon(Icons.assignment),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedCourseId,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.book),
              hintText: 'Select course',
            ),
            items: courses
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: (v) => setState(() => _selectedCourseId = v),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDeadline,
            child: InputDecorator(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.calendar_today),
                hintText: 'Select deadline',
              ),
              child: Text(
                _selectedDeadline != null
                    ? DateFormat('EEE, MMM d, y').format(_selectedDeadline!)
                    : 'Tap to pick deadline',
                style: TextStyle(
                  color: _selectedDeadline != null
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addTask,
            icon: const Icon(Icons.add),
            label: const Text('Add Task'),
          ),
          const SizedBox(height: 16),
          if (_manualTasks.isNotEmpty) ...[
            Text(
              'Tasks to add:',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.mediumGray),
            ),
            const SizedBox(height: 8),
            ..._manualTasks.asMap().entries.map(
                  (e) {
                    final t = e.value;
                    final index = e.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.event, color: AppTheme.warningOrange),
                          title: Text('${t.name} / ${t.courseName}'),
                          subtitle: Text(DateFormat('MMM d, y').format(t.deadline)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _removeTask(index),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ==================== STEP 3: STUDY TIMES ====================
  Widget _buildStudyTimesStep() {
    final times = [
      'Morning (6 AM – 12 PM)',
      'Afternoon (12 PM – 6 PM)',
      'Evening (6 PM – 10 PM)',
      'Night (10 PM – 2 AM)',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          for (var index = 0; index < times.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: CheckboxListTile(
                  title: Text(times[index]),
                  value: _preferredTimes.contains(times[index]),
                  onChanged: (value) {
                    setState(() {
                      final time = times[index];
                      value == true
                          ? _preferredTimes.add(time)
                          : _preferredTimes.remove(time);
                    });
                  },
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ManualTask {
  final String name;
  final DateTime deadline;
  final String courseId;
  final String courseName;

  _ManualTask({
    required this.name,
    required this.deadline,
    required this.courseId,
    required this.courseName,
  });
}
