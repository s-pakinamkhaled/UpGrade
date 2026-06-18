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

/// Pops overlay routes (e.g. notifications, profile) back to [routeHome].
/// Falls back to opening home when there is nothing to pop (direct/deep link).
void returnToMainShellFromOverlay(BuildContext context) {
  final navigator = Navigator.of(context);
  var reachedHome = false;

  navigator.popUntil((route) {
    if (route.settings.name == AppConstants.routeHome) {
      reachedHome = true;
      return true;
    }
    return route.isFirst;
  });

  if (!reachedHome && context.mounted) {
    navigator.pushNamedAndRemoveUntil(
      AppConstants.routeHome,
      (route) => false,
    );
  }
}
