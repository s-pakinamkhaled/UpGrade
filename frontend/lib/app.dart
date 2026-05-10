import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'core/constants.dart';

import 'screens/login_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
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
import 'screens/past_tasks_screen.dart';
import 'screens/missed_tasks_screen.dart';
import 'screens/firestore_example_screen.dart';
import 'screens/study_plan_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/privacy_settings_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/end_session_screen.dart';
import 'screens/manual_courses_screen.dart';

import 'models/task.dart';
import 'widgets/app_logo.dart';
import 'widgets/dashboard_shell_row.dart';
import 'providers/dashboard_shell_provider.dart';
import 'providers/settings_provider.dart';

class UpGradeApp extends StatefulWidget {
  const UpGradeApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// يستدعى عند استقبال Deep Link (studyplanner://open) لفتح الشاشة الرئيسية.
  static void navigateToHome() {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppConstants.routeHome,
      (route) => false,
    );
  }

  @override
  State<UpGradeApp> createState() => _UpGradeAppState();
}

class _UpGradeAppState extends State<UpGradeApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initDeepLinks());
  }

  Future<void> _handleUri(Uri? uri) async {
    if (uri == null) return;
    // upgrade://pair?session=xxx → الموبايل يحدّث Firestore والويب يكتشف ويظهر Connected
    if (uri.scheme == 'upgrade' && uri.host == 'pair') {
      final sessionId = uri.queryParameters['session'];
      if (sessionId != null && sessionId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('pairing_sessions')
              .doc(sessionId)
              .update({'paired': true, 'device': 'Mobile device'});
        } catch (_) {}
      }
      UpGradeApp.navigateToHome();
      return;
    }
    if (uri.toString().startsWith('${AppConstants.deepLinkScheme}://')) {
      UpGradeApp.navigateToHome();
    }
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();
    try {
      final uri = await appLinks.getInitialLink();
      await _handleUri(uri);
    } catch (_) {}
    appLinks.uriLinkStream.listen((Uri? uri) async {
      await _handleUri(uri);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    return MaterialApp(
      navigatorKey: UpGradeApp.navigatorKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      initialRoute: AppConstants.routeLogin,
      routes: {
        AppConstants.routeLogin: (context) => const LoginScreen(),
        AppConstants.routeRegister: (context) => const RegisterScreen(),
        AppConstants.routeForgotPassword: (context) =>
            const ForgotPasswordScreen(),
        AppConstants.routeGoogleClassroomSync: (context) =>
            const GoogleClassroomSyncScreen(),
        AppConstants.routeDevicePairing: (context) =>
            const DevicePairingScreen(),
        AppConstants.routeOnboarding: (context) => const OnboardingScreen(),
        AppConstants.routeHome: (context) => const MainNavigationScreen(),

        // ---------- TASK EXECUTION ----------
        AppConstants.routeTaskExecution: (context) {
          final task = ModalRoute.of(context)?.settings.arguments as Task?;
          if (task == null) {
            return const Scaffold(
              body: Center(child: Text('Task not found')),
            );
          }
          return TaskExecutionScreen(task: task);
        },

        // ---------- WEEKLY SCHEDULE (NEW) ----------
        AppConstants.routeWeeklySchedule: (context) {
          final args = ModalRoute.of(context)?.settings.arguments
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
       AppConstants.routeWarnings: (context) => const WarningsScreen(),
AppConstants.routeProgress: (context) =>
    const ProgressDashboardScreen(),
AppConstants.routeBurnout: (context) => const BurnoutRiskScreen(),
AppConstants.routeGroupStudy: (context) => const GroupStudyScreen(),
AppConstants.routeAIChatbot: (context) => const AIChatbotScreen(),
AppConstants.routeEndOfDay: (context) => EndOfDayScreen(),
AppConstants.routePastTasks: (context) => const PastTasksScreen(),
AppConstants.routeMissedTasks: (context) => const MissedTasksScreen(),
AppConstants.routeFirestoreExample: (context) =>
    const FirestoreExampleScreen(),

AppConstants.routeProfile: (context) => const ProfileScreen(),

AppConstants.routePrivacy: (context) =>
    const PrivacyPolicyScreen(),

AppConstants.routePrivacySettings: (context) =>
    const PrivacySettingsScreen(),

AppConstants.routeEditProfile: (context) =>
    const EditProfileScreen(),

AppConstants.routeStudyPlan: (context) => const StudyPlanScreen(),
AppConstants.routeQrScanner: (context) => const QrScannerScreen(),
AppConstants.routeManualCourses: (context) =>
    const ManualCoursesScreen(),

// =======================================================
// MAIN NAVIGATION
// =======================================================

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  Future<void> _performSignOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    context.read<DashboardShellProvider>().resetForNewSession();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppConstants.routeLogin,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<DashboardShellProvider>();
    final useSidebarLayout = MediaQuery.sizeOf(context).width >= 700;

    if (useSidebarLayout) {
      return Scaffold(
        body: DashboardShellRow(
          body: IndexedStack(
            index: shell.currentIndex,
            children: [
              DailyPlannerScreen(openDrawer: null),
              AIChatbotScreen(openDrawer: null),
              const ProgressDashboardScreen(showAppBar: false),
              GroupStudyScreen(openDrawer: null),
              EndSessionScreen(
                onContinue: () {
                  context
                      .read<DashboardShellProvider>()
                      .exitEndSessionContinue();
                },
                onEndAndSignOut: _performSignOut,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      body: IndexedStack(
        index: shell.currentIndex,
        children: [
          DailyPlannerScreen(openDrawer: _openDrawer),
          AIChatbotScreen(openDrawer: _openDrawer),
          ProgressDashboardScreen(openDrawer: _openDrawer),
          GroupStudyScreen(openDrawer: _openDrawer),
          EndSessionScreen(
            onContinue: () {
              context.read<DashboardShellProvider>().exitEndSessionContinue();
            },
            onEndAndSignOut: _performSignOut,
          ),
        ],
      ),
      bottomNavigationBar: shell.currentIndex == 4
          ? null
          : NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (index) {
                context.read<DashboardShellProvider>().selectTab(index);
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
        decoration: shell.currentIndex == 4
            ? null
            : BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: AppTheme.mediumShadow,
              ),
        child: shell.currentIndex == 4
            ? const SizedBox.shrink()
            : FloatingActionButton(
                onPressed: () {
                  context
                      .read<DashboardShellProvider>()
                      .selectRoute(AppConstants.routeWarnings);
                  Navigator.of(context).pushNamed(AppConstants.routeWarnings);
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
    final shell = context.read<DashboardShellProvider>();

    void selectMainRoute(String route) {
      Navigator.pop(context);
      shell.selectRoute(route);
    }

    void navigateToOverlayRoute(String route) {
      Navigator.pop(context);
      shell.selectRoute(route);
      Navigator.of(context).pushNamed(route);
    }

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
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
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            onTap: () {
              navigateToOverlayRoute(AppConstants.routeProfile);
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_outlined),
            title: const Text('My courses'),
            subtitle: const Text('Add classes not in Classroom'),
            onTap: () {
              navigateToOverlayRoute(AppConstants.routeManualCourses);
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner),
            title: const Text('Connect Desktop'),
            subtitle: const Text('Scan QR on laptop'),
            onTap: () {
              navigateToOverlayRoute(AppConstants.routeQrScanner);
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('AI Assistant'),
            onTap: () {
              selectMainRoute(AppConstants.routeAIChatbot);
            },
          ),
          ListTile(
            leading: const Icon(Icons.history_edu),
            title: const Text('Past Tasks'),
            onTap: () {
              navigateToOverlayRoute(AppConstants.routePastTasks);
            },
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Progress Dashboard'),
            onTap: () {
              selectMainRoute(AppConstants.routeProgress);
            },
          ),
          ListTile(
            leading: const Icon(Icons.health_and_safety),
            title: const Text('Burnout Risk'),
            onTap: () {
              navigateToOverlayRoute(AppConstants.routeBurnout);
            },
          ),
          ListTile(
            leading: const Icon(Icons.groups),
            title: const Text('Group Study'),
            onTap: () {
              selectMainRoute(AppConstants.routeGroupStudy);
            },
          ),
          ListTile(
            leading: const Icon(Icons.rate_review),
            title: const Text('End of Day Review'),
            onTap: () {
              navigateToOverlayRoute(AppConstants.routeEndOfDay);
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('Firestore Example'),
            onTap: () {
              navigateToOverlayRoute(AppConstants.routeFirestoreExample);
            },
          ),
        ],
      ),
    );
  }
}
