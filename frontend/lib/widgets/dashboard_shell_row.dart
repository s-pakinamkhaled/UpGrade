import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/dashboard_shell_provider.dart';
import 'dashboard_sidebar.dart';

/// Left sidebar / rail + main content. Used on home (wide) and on routes that should keep the shell.
class DashboardShellRow extends StatelessWidget {
  final Widget body;
  /// When this route is shown inside the shell (e.g. Manual Courses), pop the overlay route after sidebar actions.
  final bool popOverlayRouteAfterSidebarAction;

  const DashboardShellRow({
    super.key,
    required this.body,
    this.popOverlayRouteAfterSidebarAction = false,
  });

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<DashboardShellProvider>();
    final currentName = ModalRoute.of(context)?.settings.name;
    print(
      'SHELL ROW: currentName=$currentName, selectedRoute=${shell.selectedRoute}, currentIndex=${shell.currentIndex}',
    );

    // Keep one source of truth: provider.selectedRoute.
    // If this shell is rendered on a named overlay route, sync provider once.
    if (currentName != null &&
        currentName != AppConstants.routeHome &&
        shell.selectedRoute != currentName) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.read<DashboardShellProvider>().selectRoute(currentName);
        }
      });
    }

    void popOverlayIfNeeded() {
      final nav = Navigator.of(context);
      if (popOverlayRouteAfterSidebarAction && nav.canPop()) {
        nav.pop();
      }
    }

    void navigateFromSidebar(String route) {
      final nav = Navigator.of(context);
      final currentName = ModalRoute.of(context)?.settings.name;
      if (currentName == route) return;
      shell.selectRoute(route);

      if (popOverlayRouteAfterSidebarAction && nav.canPop()) {
        nav.pop();
      }
      nav.pushNamed(route);
    }

    void selectRoute(String route) {
      shell.selectRoute(route);
      popOverlayIfNeeded();
    }

    void enterEndSession() {
      shell.enterEndSession();
      popOverlayIfNeeded();
    }

    final resolvedSelectedRoute = shell.selectedRoute;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: shell.sidebarExpanded
              ? DashboardSidebar.effectiveWidth(context)
              : DashboardSidebarCollapsedRail.railWidth,
          child: shell.sidebarExpanded
              ? DashboardSidebar(
                  selectedRoute: resolvedSelectedRoute,
                  onSelectRoute: selectRoute,
                  onNavigateToRoute: navigateFromSidebar,
                  onEndSession: enterEndSession,
                  onCollapse: () => shell.setSidebarExpanded(false),
                )
              : DashboardSidebarCollapsedRail(
                  selectedRoute: resolvedSelectedRoute,
                  onExpand: () => shell.setSidebarExpanded(true),
                  onSelectRoute: selectRoute,
                  onNavigateToRoute: navigateFromSidebar,
                  onEndSession: enterEndSession,
                ),
        ),
        Expanded(child: body),
      ],
    );
  }
}
