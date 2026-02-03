import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../widgets/app_logo.dart';
import '../widgets/gradient_card.dart';
import '../services/google_auth_service.dart';
import '../services/classroom_sync_service.dart';
import 'dart:convert';



class GoogleClassroomSyncScreen extends StatefulWidget {
  const GoogleClassroomSyncScreen({super.key});
  
  @override
  State<GoogleClassroomSyncScreen> createState() => _GoogleClassroomSyncScreenState();
}

class _GoogleClassroomSyncScreenState extends State<GoogleClassroomSyncScreen> {
  bool _isSyncing = false;
  
  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);

    try {
      // 1️⃣ Google login + access token
      final accessToken =
          await GoogleAuthService.signInAndGetToken();

      if (accessToken == null) {
        throw Exception('Google sign-in cancelled');
      }

      // 2️⃣ Sync Classroom data
      final syncResult =
    await ClassroomSyncService.syncAll(accessToken);

          print('===== CLASSROOM SYNC RESULT =====');
          print(jsonEncode(syncResult));
          print('=================================');

      // 3️⃣ TODO: save locally or send to backend
      // Example:
      // await LocalStorage.saveClassroomData(syncResult);

      if (!mounted) return;

      // 4️⃣ Go to next step
      Navigator.of(context).pushReplacementNamed(
        AppConstants.routeDevicePairing,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: ${e.toString()}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  
  void _handleSkip() {
    // Navigate to device pairing without syncing
    Navigator.of(context).pushReplacementNamed(AppConstants.routeDevicePairing);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // Logo
              const Center(
                child: AppLogo.large(),
              ),
              
              const SizedBox(height: 40),
              
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
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.mediumShadow,
                ),
                child: ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _handleSync,
                  icon: _isSyncing
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
                    _isSyncing ? 'Syncing...' : 'Sync Now',
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
              ),
              
              const SizedBox(height: 16),
              
              // Skip Button
              TextButton(
                onPressed: _isSyncing ? null : _handleSkip,
                child: Text(
                  'Skip for now',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.darkText.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
}
