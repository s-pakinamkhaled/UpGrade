import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/core/constants.dart';
import 'package:upgrade/providers/dashboard_shell_provider.dart';

import 'helpers/integration_app_harness.dart';

void main() {
  group('Dashboard shell navigation (integration)', () {
    testWidgets('sidebar switches between dashboard, tasks, and warnings tabs',
        (tester) async {
      await tester.binding.setSurfaceSize(kIntegrationDesktopSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildDashboardIntegrationApp(viewportSize: kIntegrationDesktopSize),
      );
      await tester.pumpAndSettle();

      expect(find.text('No student data yet'), findsOneWidget);

      await tester.tap(find.text('My Tasks').first);
      await tester.pumpAndSettle();

      expect(find.text('My Tasks'), findsWidgets);

      await tester.tap(find.text('Warnings').first);
      await tester.pumpAndSettle();

      expect(find.text('Active Warnings'), findsOneWidget);
    });

    testWidgets('end session flow returns to previous tab on continue',
        (tester) async {
      await tester.binding.setSurfaceSize(kIntegrationDesktopSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildDashboardIntegrationApp(viewportSize: kIntegrationDesktopSize),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Warnings').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('End Session'));
      await tester.pumpAndSettle();

      expect(find.text('Continue Studying'), findsOneWidget);

      await tester.tap(find.text('Continue Studying'));
      await tester.pumpAndSettle();

      expect(find.text('Active Warnings'), findsOneWidget);
    });

    testWidgets('mobile bottom nav switches dashboard and tasks tabs', (tester) async {
      await tester.binding.setSurfaceSize(kIntegrationMobileSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildDashboardIntegrationApp(viewportSize: kIntegrationMobileSize),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0);

      await tester.tap(find.text('My Tasks').last);
      await tester.pumpAndSettle();

      expect(find.text('My Tasks'), findsWidgets);

      await tester.tap(find.text('Dashboard').last);
      await tester.pumpAndSettle();

      expect(find.text('No student data yet'), findsOneWidget);
    });

    testWidgets('provider state tracks shell route after sidebar navigation',
        (tester) async {
      await tester.binding.setSurfaceSize(kIntegrationDesktopSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final shell = DashboardShellProvider();

      await tester.pumpWidget(
        buildDashboardIntegrationApp(
          shellProvider: shell,
          viewportSize: kIntegrationDesktopSize,
        ),
      );
      await tester.pumpAndSettle();

      expect(shell.selectedRoute, AppConstants.routeProgress);

      await tester.tap(find.text('Warnings').first);
      await tester.pumpAndSettle();

      expect(shell.selectedRoute, AppConstants.routeWarnings);
      expect(shell.currentIndex, 5);
    });
  });
}
