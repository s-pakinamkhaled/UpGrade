import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/dashboard_shell_provider.dart';
import 'constants.dart';

/// After login / register: show the welcome screen with the **sync card** first; user taps
/// “Sync with Google Classroom” to open the full sync tab ([openGoogleClassroomSyncForReturningUser]).
void openWelcomeSyncChoiceAfterAuth(BuildContext context) {
  Navigator.of(context).pushNamedAndRemoveUntil(
    AppConstants.routeWelcomeSyncChoice,
    (route) => false,
  );
}

/// Opens Google Classroom sync inside the main shell (used from welcome sync choice).
void openGoogleClassroomSyncForReturningUser(BuildContext context) {
  final shell = context.read<DashboardShellProvider>();
  shell.setGoogleClassroomFromPostLoginSetup(true);
  shell.selectRoute(AppConstants.routeGoogleClassroomSync);
  Navigator.of(context).pushNamedAndRemoveUntil(
    AppConstants.routeHome,
    (route) => false,
  );
}
