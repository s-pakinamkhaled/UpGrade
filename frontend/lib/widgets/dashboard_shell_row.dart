import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/dashboard_shell_navigation.dart';
import '../providers/dashboard_shell_provider.dart';
import 'dashboard_sidebar.dart';
import 'upgrade_visual_system.dart';

/// Sidebar + main body for [MainNavigationScreen] only.
/// Main tabs switch via [DashboardShellProvider.selectRoute]; auxiliary items use [Navigator.pushNamed].
class DashboardShellRow extends StatelessWidget {
  final Widget body;

  const DashboardShellRow({super.key, required this.body});

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<DashboardShellProvider>();
    final layoutW = MediaQuery.sizeOf(context).width;
    final sidebarColumnWidth = layoutW >= 900
        ? DashboardSidebar.effectiveWidth(context)
        : DashboardSidebarCollapsedRail.railWidth;
    final useExpandedSidebar =
        layoutW >= 900 && shell.sidebarExpanded;

    if (kDebugMode) {
      final currentName = ModalRoute.of(context)?.settings.name;
      debugPrint(
        'SHELL ROW: currentName=$currentName, selectedRoute=${shell.selectedRoute}, currentIndex=${shell.currentIndex}',
      );
    }

    void navigateFromSidebar(String route) {
      if (route == AppConstants.routeEndSession) {
        context.read<DashboardShellProvider>().enterEndSession();
        return;
      }
      context.read<DashboardShellProvider>().selectRoute(route);
    }

    void pushAuxiliaryFromSidebar(String route) {
      Navigator.of(context).pushNamed(route);
    }

    void enterEndSession() {
      enterMainShellEndSession(context);
    }

    final resolvedSelectedRoute = shell.selectedRoute;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: sidebarColumnWidth,
          child: useExpandedSidebar
              ? DashboardSidebar(
                  selectedRoute: resolvedSelectedRoute,
                  onSelectShellRoute: navigateFromSidebar,
                  onPushAuxiliaryRoute: pushAuxiliaryFromSidebar,
                  onEndSession: enterEndSession,
                  onCollapse: () => shell.setSidebarExpanded(false),
                )
              : DashboardSidebarCollapsedRail(
                  selectedRoute: resolvedSelectedRoute,
                  onExpand: () {
                    if (layoutW >= 900) {
                      shell.setSidebarExpanded(true);
                    }
                  },
                  onSelectShellRoute: navigateFromSidebar,
                  onPushAuxiliaryRoute: pushAuxiliaryFromSidebar,
                  onEndSession: enterEndSession,
                ),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: UpGradePageDecor.pageBackground(
              Theme.of(context).brightness == Brightness.dark,
            ),
            child: body,
          ),
        ),
      ],
    );
  }
}
