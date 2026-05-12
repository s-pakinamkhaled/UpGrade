import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'constants.dart';
import '../providers/dashboard_shell_provider.dart';

/// Switches a main-shell [IndexedStack] tab and pops overlay routes to [routeHome].
/// Use only for [DashboardShellProvider.isMainShellTabRoute] targets — never [Navigator.pushNamed].
void selectMainShellRoute(BuildContext context, String route) {
  assert(
    DashboardShellProvider.isMainShellTabRoute(route),
    'selectMainShellRoute: $route is not a main shell tab',
  );
  context.read<DashboardShellProvider>().selectRoute(route);
  Navigator.of(context).popUntil(
    (r) => r.settings.name == AppConstants.routeHome || r.isFirst,
  );
}

/// Shows [EndSessionScreen] inside the shell and returns to [routeHome] if overlays are open.
void enterMainShellEndSession(BuildContext context) {
  context.read<DashboardShellProvider>().enterEndSession();
  Navigator.of(context).popUntil(
    (r) => r.settings.name == AppConstants.routeHome || r.isFirst,
  );
}
