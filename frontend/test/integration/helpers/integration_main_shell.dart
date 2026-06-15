import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:upgrade/providers/dashboard_shell_provider.dart';
import 'package:upgrade/screens/daily_planner_screen.dart';
import 'package:upgrade/screens/end_session_screen.dart';
import 'package:upgrade/screens/progress_dashboard_screen.dart';
import 'package:upgrade/screens/warnings_screen.dart';
import 'package:upgrade/widgets/dashboard_shell_row.dart';
import 'package:upgrade/widgets/upgrade_visual_system.dart';

/// Lazy shell for integration tests — builds only the active tab so Firebase-backed
/// screens (Profile, Groups, AI Chat, etc.) are never mounted without Firebase init.
class IntegrationMainShell extends StatelessWidget {
  const IntegrationMainShell({super.key});

  static const Set<int> _supportedIndices = {0, 1, 5, 9};

  Widget _bodyForIndex(int index, BuildContext context) {
    switch (index) {
      case 0:
        return const ProgressDashboardScreen(showAppBar: false);
      case 1:
        return const DailyPlannerScreen();
      case 5:
        return const WarningsScreen();
      case 9:
        return EndSessionScreen(
          onContinue: () {
            context.read<DashboardShellProvider>().exitEndSessionContinue();
          },
          onEndAndSignOut: () async {},
        );
      default:
        return const ProgressDashboardScreen(showAppBar: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<DashboardShellProvider>();
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final isTablet = width >= 600;

    final activeIndex =
        _supportedIndices.contains(shell.currentIndex) ? shell.currentIndex : 0;
    final body = _bodyForIndex(activeIndex, context);

    if (isDesktop || isTablet) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: DashboardShellRow(body: body),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('UpGrade')),
      body: DecoratedBox(
        decoration: UpGradePageDecor.pageBackground(
          Theme.of(context).brightness == Brightness.dark,
        ),
        child: body,
      ),
      bottomNavigationBar: shell.currentIndex >= 8 ||
              !const {0, 1}.contains(shell.currentIndex)
          ? null
          : NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (index) {
                final stackIndex = switch (index) {
                  0 => 0,
                  1 => 1,
                  _ => 0,
                };
                context.read<DashboardShellProvider>().selectTab(stackIndex);
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
              ],
            ),
    );
  }
}
