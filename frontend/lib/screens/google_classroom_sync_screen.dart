import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/constants.dart';
import '../widgets/app_logo.dart';
import '../widgets/gradient_card.dart';
import '../services/google_auth_service.dart';
import '../services/classroom_sync_service.dart';
import '../services/classroom_storage_service.dart';
import '../services/semester_filter_service.dart';
import '../providers/classroom_provider.dart';

class GoogleClassroomSyncScreen extends StatefulWidget {
  const GoogleClassroomSyncScreen({super.key});

  @override
  State<GoogleClassroomSyncScreen> createState() =>
      _GoogleClassroomSyncScreenState();
}

class _GoogleClassroomSyncScreenState extends State<GoogleClassroomSyncScreen> {
  bool _isPreparingSemesters = false;
  String? _accessToken;
  String? _selectedSemesterId;
  List<SemesterOption> _semesterOptions = const [];

  @override
  void initState() {
    super.initState();
    _loadSavedSemesterId();
  }

  Future<void> _loadSavedSemesterId() async {
    final savedId = await ClassroomStorageService.getSelectedSemesterId();
    if (!mounted) return;
    setState(() {
      _selectedSemesterId = savedId;
    });
  }

  Future<void> _prepareSemesters() async {
    if (_isPreparingSemesters) return;
    setState(() => _isPreparingSemesters = true);
    try {
      _accessToken ??= await GoogleAuthService.signInAndGetToken();
      if (_accessToken == null) {
        throw Exception('Google sign-in cancelled');
      }

      final courses = await ClassroomSyncService.fetchCourses(_accessToken!);
      final semesters = SemesterFilterService.extractSemesters(courses);
      final selected = SemesterFilterService.selectDefaultSemesterId(
        semesters,
        savedSemesterId: _selectedSemesterId,
      );

      if (!mounted) return;
      setState(() {
        _semesterOptions = semesters;
        _selectedSemesterId = selected;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load semesters: $e')));
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
      if (_semesterOptions.isEmpty) {
        await _prepareSemesters();
      }
      if (_semesterOptions.isEmpty || _selectedSemesterId == null) {
        throw Exception('Please load and select a semester first');
      }

      _accessToken ??= await GoogleAuthService.signInAndGetToken();
      if (_accessToken == null) {
        throw Exception('Google sign-in cancelled');
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
      final coursesCount = provider.courses.length;
      final selectedLabel = _selectedSemesterLabel;
      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Synced $count assignments from $coursesCount courses ($selectedLabel)',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No assignments found. Check the console for debug output. '
              'If you previously signed in, try signing out of Google in device settings and sync again.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
      Navigator.of(context).pushReplacementNamed(
        AppConstants.routeDevicePairing,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: ${e.toString()}')),
      );
    }
  }

  
  void _handleSkip() {
    // Navigate to device pairing without syncing
    Navigator.of(context).pushReplacementNamed(AppConstants.routeDevicePairing);
  }
  
  @override
  Widget build(BuildContext context) {
    final selectedLabel = _selectedSemesterLabel;
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              
              // Logo
              const Center(
                child: AppLogo.large(),
              ),
              
              const SizedBox(height: 40),

              // Semester filter section
              GradientCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Semester to Sync',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Choose which semester\'s courses and assignments should be imported.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.darkText.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_semesterOptions.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: _selectedSemesterId,
                        decoration: const InputDecoration(
                          labelText: 'Semester',
                          border: OutlineInputBorder(),
                        ),
                        items: _semesterOptions
                            .map(
                              (s) => DropdownMenuItem<String>(
                                value: s.id,
                                child: Text(s.label),
                              ),
                            )
                            .toList(),
                        onChanged: _isPreparingSemesters
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => _selectedSemesterId = value);
                                ClassroomStorageService.saveSelectedSemesterId(
                                  value,
                                );
                              },
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _isPreparingSemesters ? null : _prepareSemesters,
                        icon: _isPreparingSemesters
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.school_outlined),
                        label: Text(
                          _isPreparingSemesters
                              ? 'Loading semesters...'
                              : 'Connect Google & Load Semesters',
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Sync target: $selectedLabel',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              
              // Main Title
              const Text(
                'Sync Google Classroom',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // Subtitle
              Text(
                'Auto-import assignments, deadlines & grades',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.darkText.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 48),
              
              // Google Classroom Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.softGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.softShadow,
                ),
                child: const Icon(
                  Icons.class_,
                  size: 64,
                  color: AppTheme.primaryBlue,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Benefits Section
              GradientCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: AppTheme.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'What You\'ll Get',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _buildBenefit(
                      Icons.assignment,
                      'Automatic Assignment Import',
                      'All your assignments and deadlines sync automatically',
                      AppTheme.primaryBlue,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    _buildBenefit(
                      Icons.calendar_today,
                      'Smart Scheduling',
                      'Tasks are automatically organized in your planner',
                      AppTheme.secondaryPurple,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    _buildBenefit(
                      Icons.grade,
                      'Grade Tracking',
                      'Monitor your progress and grades in one place',
                      AppTheme.successGreen,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    _buildBenefit(
                      Icons.notifications_active,
                      'Deadline Alerts',
                      'Never miss an assignment with proactive reminders',
                      AppTheme.warningOrange,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Privacy Note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your data is secure. We only access your classroom data to help organize your studies.',
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
              
              const SizedBox(height: 40),
              
              // Sync Now Button
              Consumer<ClassroomProvider>(
                builder: (context, provider, _) {
                  final isLoading = provider.isLoading || _isPreparingSemesters;
                  final canSync = _selectedSemesterId != null &&
                      _semesterOptions.isNotEmpty;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.mediumShadow,
                    ),
                    child: ElevatedButton.icon(
                      onPressed: isLoading || !canSync ? null : _handleSync,
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                              ),
                            )
                          : const Icon(Icons.sync, size: 20),
                      label: Text(
                        isLoading ? 'Syncing...' : 'Sync Now',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Skip Button
              Consumer<ClassroomProvider>(
                builder: (context, provider, _) {
                  return TextButton(
                    onPressed: provider.isLoading ? null : _handleSkip,
                    child: Text(
                      'Skip for now',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.darkText.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),
              
              // Help Text
              Text(
                'You can always sync later from Settings',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.mediumGray,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBenefit(IconData icon, String title, String description, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.darkText.withOpacity(0.7),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
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
