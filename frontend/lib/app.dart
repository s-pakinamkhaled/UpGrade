import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'core/constants.dart';
import 'core/dashboard_shell_navigation.dart';

import 'services/device_pairing_storage_service.dart';
import 'screens/login_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/google_classroom_sync_screen.dart';
import 'screens/device_pairing_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_sync_choice_screen.dart';
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
import 'screens/notifications_screen.dart';

import 'models/task.dart';
import 'widgets/app_logo.dart';
import 'widgets/dashboard_shell_row.dart';
import 'widgets/notification_bell_button.dart';
import 'widgets/upgrade_visual_system.dart';
import 'providers/classroom_provider.dart';
import 'providers/dashboard_shell_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/notification_provider.dart';

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
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            await DevicePairingStorageService.setPaired(
              uid: uid,
              paired: true,
              deviceName: 'Mobile device',
            );
          }
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
        AppConstants.routeGoogleClassroomSync: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final fromPostLogin = args == true;
          return GoogleClassroomSyncScreen(fromPostLoginSetup: fromPostLogin);
        },
        AppConstants.routeWelcomeSyncChoice: (context) =>
            const WelcomeSyncChoiceScreen(),
        AppConstants.routeDevicePairing: (context) =>
            const DevicePairingScreen(),
        AppConstants.routeOnboarding: (context) => const OnboardingScreen(),
        AppConstants.routeHome: (context) => const MainNavigationScreen(),

        AppConstants.routeDailyPlanner: (context) =>
            const DailyPlannerScreen(),

        AppConstants.routeEndSession: (context) => EndSessionScreen(
              onContinue: () {
                Navigator.of(context).pop();
              },
              onEndAndSignOut: () async {
                await context.read<ClassroomProvider>().clearUserData();
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                context.read<DashboardShellProvider>().resetForNewSession();
                context.read<NotificationProvider>().resetForNewSession();
                if (!context.mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppConstants.routeLogin,
                  (route) => false,
                );
              },
            ),

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
AppConstants.routeNotifications: (context) => const NotificationsScreen(),
AppConstants.routeProgress: (context) =>
    const ProgressDashboardScreen(showAppBar: false),
AppConstants.routeBurnout: (context) => const BurnoutRiskScreen(),
AppConstants.routeGroupStudy: (context) => const GroupStudyScreen(),
AppConstants.routeAIChatbot: (context) => const AIChatbotScreen(),
AppConstants.routeEndOfDay: (context) => EndOfDayScreen(),
AppConstants.routePastTasks: (context) => const PastTasksScreen(),
AppConstants.routeMissedTasks: (context) => const MissedTasksScreen(),
AppConstants.routeFirestoreExample: (context) =>
    const FirestoreExampleScreen(),

AppConstants.routeProfile: (context) => const ProfileScreen(),

AppConstants.routePrivacy: (context) => const PrivacyPolicyScreen(),

AppConstants.routePrivacySettings: (context) =>
    const PrivacySettingsScreen(),

AppConstants.routeEditProfile: (context) =>
    const EditProfileScreen(),

AppConstants.routeStudyPlan: (context) => const StudyPlanScreen(),
AppConstants.routeQrScanner: (context) => const QrScannerScreen(),
        AppConstants.routeManualCourses: (context) =>
            const _RedirectManualCoursesToShellTab(),
      },
    );
  }
}

// =======================================================
// MANUAL COURSES: fold named-route opens into shell tab
// =======================================================

/// If anything still calls [Navigator.pushNamed] for [AppConstants.routeManualCourses],
/// we switch the [IndexedStack] tab and pop back to [routeHome] so the sidebar stays visible.
class _RedirectManualCoursesToShellTab extends StatefulWidget {
  const _RedirectManualCoursesToShellTab();

  @override
  State<_RedirectManualCoursesToShellTab> createState() =>
      _RedirectManualCoursesToShellTabState();
}

class _RedirectManualCoursesToShellTabState
    extends State<_RedirectManualCoursesToShellTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      selectMainShellRoute(context, AppConstants.routeManualCourses);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.shrink(),
    );
  }
}

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
  late final Widget _shellIndexedStack = const _MainShellIndexedStack();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<ClassroomProvider>().syncTasksToBackend();
      if (!mounted) return;
      await context.read<ClassroomProvider>().syncDeadlineNotifications();
      if (!mounted) return;
      context.read<NotificationProvider>().startListening();
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final isTablet = width >= 600;

    if (isDesktop || isTablet) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: DashboardShellRow(
          body: _shellIndexedStack,
        ),
      );
    }

    return Selector<DashboardShellProvider, int>(
      selector: (_, shell) => shell.currentIndex,
      builder: (context, currentIndex, child) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.transparent,
          drawer: _buildDrawer(context),
          appBar: AppBar(
            title: const Text('UpGrade'),
            actions: const [
              NotificationBellButton(),
            ],
          ),
          body: DecoratedBox(
            decoration: UpGradePageDecor.pageBackground(
              Theme.of(context).brightness == Brightness.dark,
            ),
            child: child!,
          ),
          bottomNavigationBar: currentIndex >= 8 ||
                  !const {0, 1, 2, 4}.contains(currentIndex)
              ? null
              : NavigationBar(
                  selectedIndex: currentIndex == 4 ? 3 : currentIndex,
                  onDestinationSelected: (index) {
                    final stackIndex = switch (index) {
                      0 => 0,
                      1 => 1,
                      2 => 2,
                      _ => 4,
                    };
                    context
                        .read<DashboardShellProvider>()
                        .selectTab(stackIndex);
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: 'Dashboard',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_today_outlined),
                      selectedIcon: Icon(Icons.calendar_today),
                      label: 'My Tasks',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.auto_awesome_outlined),
                      selectedIcon: Icon(Icons.auto_awesome),
                      label: 'AI Chat',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.groups_outlined),
                      selectedIcon: Icon(Icons.groups),
                      label: 'Groups',
                    ),
                  ],
                ),
        );
      },
      child: _shellIndexedStack,
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    void pushRoute(String route) {
      Navigator.pop(context);
      if (DashboardShellProvider.isMainShellTabRoute(route)) {
        selectMainShellRoute(context, route);
      } else {
        Navigator.of(context).pushNamed(route);
      }
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
              pushRoute(AppConstants.routeProfile);
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_outlined),
            title: const Text('My courses'),
            subtitle: const Text('Add classes not in Classroom'),
            onTap: () {
              pushRoute(AppConstants.routeManualCourses);
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner),
            title: const Text('Connect Desktop'),
            subtitle: const Text('Scan QR on laptop'),
            onTap: () {
              pushRoute(AppConstants.routeQrScanner);
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('AI Assistant'),
            onTap: () {
              pushRoute(AppConstants.routeAIChatbot);
            },
          ),
          ListTile(
            leading: const Icon(Icons.history_edu),
            title: const Text('Past Tasks'),
            onTap: () {
              pushRoute(AppConstants.routePastTasks);
            },
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Progress Dashboard'),
            onTap: () {
              pushRoute(AppConstants.routeProgress);
            },
          ),
          ListTile(
            leading: const Icon(Icons.health_and_safety),
            title: const Text('Burnout Risk'),
            onTap: () {
              pushRoute(AppConstants.routeBurnout);
            },
          ),
          ListTile(
            leading: const Icon(Icons.groups),
            title: const Text('Study Group'),
            onTap: () {
              pushRoute(AppConstants.routeGroupStudy);
            },
          ),
          ListTile(
            leading: const Icon(Icons.rate_review),
            title: const Text('End of Day Review'),
            onTap: () {
              pushRoute(AppConstants.routeEndOfDay);
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('Firestore Example'),
            onTap: () {
              pushRoute(AppConstants.routeFirestoreExample);
            },
          ),
        ],
      ),
    );
  }
}

/// Main shell tabs — only rebuilds when [DashboardShellProvider.currentIndex]
/// or Google Classroom post-login flag changes, not on sidebar toggle.
class _MainShellIndexedStack extends StatelessWidget {
  const _MainShellIndexedStack();

  @override
  Widget build(BuildContext context) {
    return Selector<DashboardShellProvider, int>(
      selector: (_, shell) => shell.currentIndex,
      builder: (context, currentIndex, _) {
        return IndexedStack(
          index: currentIndex,
          sizing: StackFit.expand,
          children: [
            const RepaintBoundary(
              child: ProgressDashboardScreen(showAppBar: false),
            ),
            const RepaintBoundary(child: DailyPlannerScreen()),
            const RepaintBoundary(child: AIChatbotScreen()),
            const RepaintBoundary(child: StudyPlanScreen()),
            const RepaintBoundary(child: GroupStudyScreen()),
            const RepaintBoundary(child: WarningsScreen()),
            const RepaintBoundary(child: ProfileScreen(embeddedInShell: true)),
            RepaintBoundary(
              child: Selector<DashboardShellProvider, bool>(
                selector: (_, shell) => shell.googleClassroomFromPostLoginSetup,
                builder: (context, fromPostLogin, _) =>
                    GoogleClassroomSyncScreen(
                  fromPostLoginSetup: fromPostLogin,
                ),
              ),
            ),
            const RepaintBoundary(
              child: ManualCoursesScreen(embeddedInShell: true),
            ),
            RepaintBoundary(
              child: EndSessionScreen(
                onContinue: () {
                  context
                      .read<DashboardShellProvider>()
                      .exitEndSessionContinue();
                },
                onEndAndSignOut: () async {
                  await context.read<ClassroomProvider>().clearUserData();
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  context.read<DashboardShellProvider>().resetForNewSession();
                  context.read<NotificationProvider>().resetForNewSession();
                  if (!context.mounted) return;
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppConstants.routeLogin,
                    (route) => false,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

