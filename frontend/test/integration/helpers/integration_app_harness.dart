import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrade/core/constants.dart';
import 'package:upgrade/core/theme.dart';
import 'package:upgrade/providers/classroom_provider.dart';
import 'package:upgrade/providers/dashboard_shell_provider.dart';
import 'package:upgrade/providers/notification_provider.dart';
import 'package:upgrade/providers/settings_provider.dart';
import 'package:upgrade/providers/study_group_provider.dart';
import 'package:upgrade/screens/privacy_settings_screen.dart';

import 'integration_main_shell.dart';

/// Desktop/tablet size so [IntegrationMainShell] renders the sidebar rail.
const Size kIntegrationDesktopSize = Size(1920, 1080);

/// Mobile viewport — same sidebar rail shell as web.
const Size kIntegrationMobileSize = Size(390, 844);

/// Resets SharedPreferences mock storage before each integration test.
void resetIntegrationPrefs() {
  SharedPreferences.setMockInitialValues({});
}

/// Full provider tree used by dashboard integration tests (no Firebase init).
Widget buildDashboardIntegrationApp({
  ClassroomProvider? classroomProvider,
  DashboardShellProvider? shellProvider,
  String initialRoute = AppConstants.routeHome,
  Size? viewportSize,
}) {
  resetIntegrationPrefs();

  final classroom = classroomProvider ?? ClassroomProvider();
  final shell = shellProvider ?? DashboardShellProvider()
    ..setSidebarExpanded(true);

  final app = MultiProvider(
    providers: [
      ChangeNotifierProvider<ClassroomProvider>.value(value: classroom),
      ChangeNotifierProvider(
        create: (_) => SettingsProvider()..load(),
      ),
      ChangeNotifierProvider<DashboardShellProvider>.value(value: shell),
      ChangeNotifierProvider(
        create: (_) => NotificationProvider(),
      ),
      ChangeNotifierProvider(
        create: (_) => StudyGroupProvider(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      initialRoute: initialRoute,
      routes: {
        AppConstants.routeHome: (context) => const IntegrationMainShell(),
        AppConstants.routePrivacySettings: (context) =>
            const PrivacySettingsScreen(),
      },
    ),
  );

  if (viewportSize != null) {
    return MediaQuery(
      data: MediaQueryData(size: viewportSize),
      child: app,
    );
  }
  return app;
}

/// Privacy settings with the same provider stack as the live app shell.
Widget buildPrivacyIntegrationApp({SettingsProvider? settingsProvider}) {
  resetIntegrationPrefs();

  final settings = settingsProvider ?? SettingsProvider();

  return ChangeNotifierProvider<SettingsProvider>.value(
    value: settings,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const PrivacySettingsScreen(),
    ),
  );
}
