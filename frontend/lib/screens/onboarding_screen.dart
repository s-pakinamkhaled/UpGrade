import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../widgets/app_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  final List<String> _courses = [];
  final List<DateTime> _deadlines = [];
  final List<String> _preferredTimes = [];

  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _deadlineController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _courseController.dispose();
    _deadlineController.dispose();
    super.dispose();
  }

  void _addCourse() {
    if (_courseController.text.isNotEmpty) {
      setState(() {
        _courses.add(_courseController.text);
        _courseController.clear();
      });
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context)
          .pushReplacementNamed(AppConstants.routeHome);
    }
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
                          gradient: index <= _currentStep
                              ? AppTheme.primaryGradient
                              : null,
                          color: index <= _currentStep
                              ? null
                              : AppTheme.mediumGray.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: index <= _currentStep
                              ? AppTheme.softShadow
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
              ),

            // Logo
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.softGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const AppLogo.large(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentStep = index;
                  });
                },
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
                          duration:
                              const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _nextStep,
                    child: Text(
                        _currentStep < 2 ? 'Next' : 'Get Started'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- STEP 1 --------------------
  Widget _buildCoursesStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Your Courses',
            style:
                TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about the courses you\'re taking this semester',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.darkText.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
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
              IconButton(
                onPressed: _addCourse,
                icon: const Icon(Icons.add_circle),
                color: AppTheme.primaryBlue,
                iconSize: 32,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_courses.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _courses.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.book,
                          color: AppTheme.primaryBlue),
                      title: Text(_courses[index]),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _courses.removeAt(index);
                          });
                        },
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

  // -------------------- STEP 2 --------------------
  Widget _buildDeadlinesStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Important Deadlines',
            style:
                TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Add any upcoming deadlines or important dates',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.darkText.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _deadlineController,
            decoration: const InputDecoration(
              hintText: 'Deadline description',
              prefixIcon: Icon(Icons.event),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _deadlines
                    .add(DateTime.now().add(const Duration(days: 7)));
              });
            },
            icon: const Icon(Icons.calendar_today),
            label: const Text('Add Deadline'),
          ),
          const SizedBox(height: 16),
          if (_deadlines.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _deadlines.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.event,
                          color: AppTheme.warningOrange),
                      title: Text(
                        _deadlineController.text.isEmpty
                            ? 'Deadline ${index + 1}'
                            : _deadlineController.text,
                      ),
                      subtitle: Text(
                        '${_deadlines[index].month}/${_deadlines[index].day}/${_deadlines[index].year}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _deadlines.removeAt(index);
                          });
                        },
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

  // -------------------- STEP 3 --------------------
  Widget _buildStudyTimesStep() {
    final times = [
      'Morning (6-12)',
      'Afternoon (12-6)',
      'Evening (6-10)',
      'Night (10-2)'
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preferred Study Times',
            style:
                TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'When do you prefer to study? (You can select multiple)',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.darkText.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: times.length,
              itemBuilder: (context, index) {
                final time = times[index];
                final isSelected =
                    _preferredTimes.contains(time);
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
          const SizedBox(height: 16),

          // ✅ FIXED: Google Classroom Card
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Google Classroom connection coming soon!'),
                ),
              );
            },
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.class_,
                        color: AppTheme.primaryBlue),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Connect Google Classroom',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Sync your assignments automatically',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}