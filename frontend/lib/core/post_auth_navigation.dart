import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/dashboard_shell_provider.dart';
import '../services/onboarding_storage_service.dart';
import 'constants.dart';

/// After login / register: onboarding for new users, otherwise the main app shell.
Future<void> navigateAfterAuth(
  BuildContext context, {
  bool forceOnboarding = false,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    openWelcomeSyncChoiceAfterAuth(context);
    return;
  }

  final hasSeen = await OnboardingStorageService.hasSeenOnboarding(uid);
  if (!context.mounted) return;

  if (forceOnboarding || !hasSeen) {
    openOnboardingAfterAuth(context);
    return;
  }

  openHomeAfterAuth(context);
}

void openOnboardingAfterAuth(BuildContext context) {
  Navigator.of(context).pushNamedAndRemoveUntil(
    AppConstants.routeOnboarding,
    (route) => false,
  );
}

/// Returning users land in the main dashboard shell.
void openHomeAfterAuth(BuildContext context) {
  final shell = context.read<DashboardShellProvider>();
  shell.selectRoute(AppConstants.routeProgress);
  Navigator.of(context).pushNamedAndRemoveUntil(
    AppConstants.routeHome,
    (route) => false,
  );
}

/// Shown once after onboarding completes (Google Classroom sync choice).
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
