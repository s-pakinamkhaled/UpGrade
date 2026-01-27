import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'core/constants.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/google_classroom_sync_screen.dart';
import 'screens/device_pairing_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/daily_planner_screen.dart';
import 'screens/weekly_schedule_screen.dart';
import 'screens/task_execution_screen.dart';
import 'screens/warnings_screen.dart';
import 'screens/progress_dashboard_screen.dart';
import 'screens/burnout_risk_screen.dart';
import 'screens/group_study_screen.dart';
import 'screens/end_of_day_screen.dart';
import 'screens/ai_chatbot_screen.dart';

import 'models/task.dart';
import 'widgets/app_logo.dart';

class UpGradeApp extends StatelessWidget {
  const UpGradeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppConstants.routeLogin,
      routes: {
        AppConstants.routeLogin: (context) => const LoginScreen(),
        AppConstants.routeRegister: (context) => const RegisterScreen(),
        AppConstants.routeGoogleClassroomSync: (context) =>
            const GoogleClassroomSyncScreen(),
        AppConstants.routeDevicePairing: (context) =>
            const DevicePairingScreen(),
        AppConstants.routeOnboarding: (context) =>
            const OnboardingScreen(),
        AppConstants.routeHome: (context) =>
            const MainNavigationScreen(),

        // ---------- TASK EXECUTION ----------
        AppConstants.routeTaskExecution: (context) {
          final task =
              ModalRoute.of(context)?.settings.arguments as Task?;
          if (task == null) {
            return const Scaffold(
              body: Center(child: Text('Task not found')),
            );
          }
          return TaskExecutionScreen(task: task);
        },

        // ---------- WEEKLY SCHEDULE (NEW) ----------
        AppConstants.routeWeeklySchedule: (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;

          if (args == null) {
            return const Scaffold(
              body: Center(child: Text('Weekly data missing')),
            );
          }

          return WeeklyScheduleScreen(
            weekStart: args['weekStart'],
            weeklyTasks: args['weeklyTasks'],
          );
        },

        // ---------- OTHER ROUTES ----------
        AppConstants.routeWarnings: (context) =>
            const WarningsScreen(),
        AppConstants.routeProgress: (context) =>
            const ProgressDashboardScreen(),
        AppConstants.routeBurnout: (context) =>
            const BurnoutRiskScreen(),
        AppConstants.routeGroupStudy: (context) =>
            const GroupStudyScreen(),
        AppConstants.routeAIChatbot: (context) =>
            const AIChatbotScreen(),
        AppConstants.routeEndOfDay: (context) =>
            EndOfDayScreen(),
      },
    );
  }
}

// =======================================================
// MAIN NAVIGATION
// =======================================================

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DailyPlannerScreen(),
    const AIChatbotScreen(),
    const ProgressDashboardScreen(),
    const GroupStudyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Planner',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'AI Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Groups',
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: AppTheme.mediumShadow,
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.of(context)
                .pushNamed(AppConstants.routeWarnings);
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Stack(
            children: [
              const Icon(
                Icons.notifications_rounded,
                color: AppTheme.white,
                size: 24,
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: AppTheme.errorRed,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      drawer: _buildDrawer(context),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration:
                BoxDecoration(gradient: AppTheme.primaryGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const AppLogo.small(),
                ),
                const SizedBox(height: 20),
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppConstants.appTagline,
                  style: TextStyle(
                    color: AppTheme.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('AI Assistant'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context)
                  .pushNamed(AppConstants.routeAIChatbot);
            },
          ),

          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Progress Dashboard'),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 2);
            },
          ),

          ListTile(
            leading: const Icon(Icons.health_and_safety),
            title: const Text('Burnout Risk'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context)
                  .pushNamed(AppConstants.routeBurnout);
            },
          ),

          ListTile(
            leading: const Icon(Icons.groups),
            title: const Text('Group Study'),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 3);
            },
          ),

          ListTile(
            leading: const Icon(Icons.rate_review),
            title: const Text('End of Day Review'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context)
                  .pushNamed(AppConstants.routeEndOfDay);
            },
          ),
        ],
      ),
    );
  }
}
