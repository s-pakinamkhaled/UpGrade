import 'package:flutter/material.dart';

import 'dashboard_shell_row.dart';

/// On wide viewports, shows [DashboardShellRow] + scrollable [wideBody].
/// On narrow viewports, shows [narrow] only (typical phone layout).
class DashboardSecondaryShell extends StatelessWidget {
  /// Route string for sidebar highlight (e.g. `/profile`, `/warnings`, `/study-plan`).
  final String highlightRoute;
  final Widget narrow;
  final Widget wideBody;

  const DashboardSecondaryShell({
    super.key,
    required this.highlightRoute,
    required this.narrow,
    required this.wideBody,
  });

  static const double breakpointWidth = 700;
  static const double maxContentWidth = 920;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= breakpointWidth;
    if (!wide) return narrow;

    final theme = Theme.of(context);
    final bg = theme.colorScheme.surfaceContainerHighest;
    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? theme.scaffoldBackgroundColor
          : bg,
      body: DashboardShellRow(
        popOverlayRouteAfterSidebarAction: true,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: maxContentWidth,
                    ),
                    child: wideBody,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
