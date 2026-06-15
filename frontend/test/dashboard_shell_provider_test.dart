import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/core/constants.dart';
import 'package:upgrade/providers/dashboard_shell_provider.dart';

void main() {
  group('DashboardShellProvider navigation flow', () {
    late DashboardShellProvider provider;

    setUp(() {
      provider = DashboardShellProvider();
    });

    test('starts on dashboard tab', () {
      expect(provider.selectedRoute, AppConstants.routeProgress);
      expect(provider.currentIndex, 0);
      expect(provider.sidebarExpanded, isTrue);
    });

    test('selectTab switches indexed stack route', () {
      provider.selectTab(2);
      expect(provider.selectedRoute, AppConstants.routeAIChatbot);
      expect(provider.currentIndex, 2);
    });

    test('selectRoute ignores non-shell routes', () {
      provider.selectRoute(AppConstants.routeQrScanner);
      expect(provider.selectedRoute, AppConstants.routeProgress);
    });

    test('selectRoute updates shell tab highlight', () {
      provider.selectRoute(AppConstants.routeDailyPlanner);
      expect(provider.selectedRoute, AppConstants.routeDailyPlanner);
      expect(provider.currentIndex, 1);
    });

    test('end session flow saves and restores previous route', () {
      provider.selectRoute(AppConstants.routeProfile);
      provider.enterEndSession();

      expect(provider.selectedRoute, AppConstants.routeEndSession);
      expect(provider.currentIndex, 9);

      provider.exitEndSessionContinue();
      expect(provider.selectedRoute, AppConstants.routeProfile);
    });

    test('sidebar expand/collapse toggles state', () {
      provider.setSidebarExpanded(false);
      expect(provider.sidebarExpanded, isFalse);

      provider.setSidebarExpanded(false);
      provider.setSidebarExpanded(true);
      expect(provider.sidebarExpanded, isTrue);
    });

    test('resetForNewSession clears session navigation state', () {
      provider.selectRoute(AppConstants.routeGroupStudy);
      provider.setSidebarExpanded(true);
      provider.setGoogleClassroomFromPostLoginSetup(true);

      provider.resetForNewSession();

      expect(provider.selectedRoute, AppConstants.routeProgress);
      expect(provider.sidebarExpanded, isFalse);
      expect(provider.googleClassroomFromPostLoginSetup, isFalse);
    });
  });

  group('DashboardShellProvider.isMainShellTabRoute', () {
    test('returns true for main shell tabs', () {
      expect(
        DashboardShellProvider.isMainShellTabRoute(AppConstants.routeProgress),
        isTrue,
      );
      expect(
        DashboardShellProvider.isMainShellTabRoute(
          AppConstants.routeManualCourses,
        ),
        isTrue,
      );
    });

    test('returns false for auxiliary routes', () {
      expect(
        DashboardShellProvider.isMainShellTabRoute(AppConstants.routeLogin),
        isFalse,
      );
      expect(
        DashboardShellProvider.isMainShellTabRoute(AppConstants.routeEndSession),
        isFalse,
      );
      expect(
        DashboardShellProvider.isMainShellTabRoute(AppConstants.routeQrScanner),
        isFalse,
      );
    });

    test('selectRoute cannot open auth or overlay routes from shell', () {
      final shell = DashboardShellProvider();

      shell.selectRoute(AppConstants.routeLogin);
      expect(shell.selectedRoute, AppConstants.routeProgress);

      shell.selectRoute(AppConstants.routeEndSession);
      expect(shell.selectedRoute, AppConstants.routeProgress);

      shell.selectRoute(AppConstants.routeQrScanner);
      expect(shell.selectedRoute, AppConstants.routeProgress);
    });
  });
}
