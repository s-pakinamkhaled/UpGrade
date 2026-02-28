import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/constants.dart';
import 'services/auth_service.dart';
import 'providers/classroom_provider.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/google_classroom_sync_screen.dart';
import 'screens/device_pairing_screen.dart';
import 'screens/daily_planner_screen.dart';
import 'screens/weekly_schedule_screen.dart';
import 'screens/task_execution_screen.dart';
import 'screens/warnings_screen.dart';
import 'screens/progress_dashboard_screen.dart';
import 'screens/burnout_risk_screen.dart';
import 'screens/group_study_screen.dart';
import 'screens/end_of_day_screen.dart';
import 'screens/ai_chatbot_screen.dart';
import 'screens/past_tasks_screen.dart';
import 'screens/missed_tasks_screen.dart';
import 'models/task.dart';
import 'app.dart' show MainNavigationScreen;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => ClassroomProvider()..loadFromStorage(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
      routes: {
        AppConstants.routeGoogleClassroomSync: (_) =>
            const GoogleClassroomSyncScreen(),
        AppConstants.routeDevicePairing: (_) => const DevicePairingScreen(),
        AppConstants.routeHome: (_) => const MainNavigationScreen(),
        AppConstants.routeLogin: (_) => const LoginScreen(),
        AppConstants.routeWarnings: (_) => const WarningsScreen(),
        AppConstants.routeProgress: (_) => const ProgressDashboardScreen(),
        AppConstants.routeBurnout: (_) => const BurnoutRiskScreen(),
        AppConstants.routeGroupStudy: (_) => const GroupStudyScreen(),
        AppConstants.routeAIChatbot: (_) => const AIChatbotScreen(),
        AppConstants.routeEndOfDay: (_) => EndOfDayScreen(),
        AppConstants.routePastTasks: (_) => const PastTasksScreen(),
        AppConstants.routeMissedTasks: (_) => const MissedTasksScreen(),
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
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const OnboardingScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
