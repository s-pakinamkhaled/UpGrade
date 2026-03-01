import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/constants.dart';
import '../widgets/app_logo.dart';
import '../providers/classroom_provider.dart';
import '../models/classroom_course.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

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
    _pageController.dispose();
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
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      height: 5,
                      margin: EdgeInsets.only(right: index < 2 ? 10 : 0),
                      decoration: BoxDecoration(
                        gradient: index <= _currentStep ? AppTheme.primaryGradient : null,
                        color: index <= _currentStep ? null : AppTheme.mediumGray.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: index <= _currentStep ? AppTheme.softShadow : null,
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Logo
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.softGradient,
                  shape: BoxShape.circle,
                ),
                child: const AppLogo.small(),
              ),
            ),

            // Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentStep = index),
                children: [
                  _buildCoursesStep(),
                  _buildDeadlinesStep(),
                  _buildStudyTimesStep(),
                ],
              ),
            ),

            // Navigation Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _nextStep,
                    child: Text(_currentStep < 2 ? 'Next' : 'Get Started'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== STEP 1: COURSES ====================
  Widget _buildCoursesStep() {
    final syncedCourses = context.watch<ClassroomProvider>().courses;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Your Courses',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Add any extra courses not synced from Google Classroom',
            style: TextStyle(fontSize: 15, color: AppTheme.darkText.withOpacity(0.7)),
          ),
          const SizedBox(height: 20),
          Row(
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
            ...syncedCourses.map((c) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.cloud_done, color: AppTheme.successGreen),
                    title: Text(c.name),
                  ),
                )),
            const SizedBox(height: 16),
          ],
          if (_manualCourses.isNotEmpty) ...[
            Text(
              'Manual courses:',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.mediumGray),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: ListView.builder(
              itemCount: _manualCourses.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.book, color: AppTheme.primaryBlue),
                    title: Text(_manualCourses[index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _removeCourse(index),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STEP 2: DEADLINES ====================
  Widget _buildDeadlinesStep() {
    final courses = _allCourses;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Deadlines',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Add tasks/assignments with deadlines',
            style: TextStyle(fontSize: 15, color: AppTheme.darkText.withOpacity(0.7)),
          ),
          const SizedBox(height: 20),
          // Task name
          TextField(
            controller: _taskNameController,
            decoration: const InputDecoration(
              hintText: 'Task name (e.g., Essay draft)',
              prefixIcon: Icon(Icons.assignment),
            ),
          ),
          const SizedBox(height: 12),
          // Course dropdown
          DropdownButtonFormField<String>(
            value: _selectedCourseId,
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
          // Date picker
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
                  color: _selectedDeadline != null ? AppTheme.darkText : AppTheme.mediumGray,
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
          if (_manualTasks.isNotEmpty)
            Text(
              'Tasks to add:',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.mediumGray),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _manualTasks.length,
              itemBuilder: (context, index) {
                final t = _manualTasks[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.event, color: AppTheme.warningOrange),
                    title: Text('${t.name} / ${t.courseName}'),
                    subtitle: Text(DateFormat('MMM d, y').format(t.deadline)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _removeTask(index),
                    ),
                  ),
                );
              },
            ),
          ),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preferred Study Times',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'When do you prefer to study? (optional)',
            style: TextStyle(fontSize: 15, color: AppTheme.darkText.withOpacity(0.7)),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: times.length,
              itemBuilder: (context, index) {
                final time = times[index];
                final isSelected = _preferredTimes.contains(time);
                return Card(
                  child: CheckboxListTile(
                    title: Text(time),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        value == true
                            ? _preferredTimes.add(time)
                            : _preferredTimes.remove(time);
                      });
                    },
                  ),
                );
              },
            ),
          ),
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
