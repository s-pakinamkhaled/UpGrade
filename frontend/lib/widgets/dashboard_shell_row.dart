import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/dashboard_shell_provider.dart';
import 'dashboard_sidebar.dart';

/// Left sidebar / rail + main content. Used on home (wide) and on routes that should keep the shell.
class DashboardShellRow extends StatelessWidget {
  final Widget body;
  /// When this route is shown inside the shell (e.g. Manual Courses), pop the overlay route after sidebar actions.
  final bool popOverlayRouteAfterSidebarAction;
  /// Highlights "My courses" in the full sidebar / rail when non-null.
  final String? highlightRoute;

  const DashboardShellRow({
    super.key,
    required this.body,
    this.popOverlayRouteAfterSidebarAction = false,
    this.highlightRoute,
  });

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<DashboardShellProvider>();

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

      if (popOverlayRouteAfterSidebarAction && nav.canPop()) {
        nav.pop();
      }
      nav.pushNamed(route);
    }

    void selectTab(int index) {
      shell.selectTab(index);
      popOverlayIfNeeded();
    }

    void enterEndSession() {
      shell.enterEndSession();
      popOverlayIfNeeded();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: shell.sidebarExpanded
              ? DashboardSidebar.effectiveWidth(context)
              : DashboardSidebarCollapsedRail.railWidth,
          child: shell.sidebarExpanded
              ? DashboardSidebar(
                  currentIndex: shell.currentIndex,
                  highlightRoute: highlightRoute,
                  onSelectTab: selectTab,
                  onNavigateToRoute: navigateFromSidebar,
                  onEndSession: enterEndSession,
                  onCollapse: () => shell.setSidebarExpanded(false),
                )
              : DashboardSidebarCollapsedRail(
                  currentIndex: shell.currentIndex,
                  highlightRoute: highlightRoute,
                  onExpand: () => shell.setSidebarExpanded(true),
                  onSelectTab: selectTab,
                  onNavigateToRoute: navigateFromSidebar,
                  onEndSession: enterEndSession,
                ),
        ),
        Expanded(child: body),
      ],
    );
  }
}
