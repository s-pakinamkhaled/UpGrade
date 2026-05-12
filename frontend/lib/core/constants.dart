class AppConstants {
  // ================== COLORS ==================
  static const String primaryBlue = '#3b82f6';
  static const String secondaryPurple = '#8b5cf6';
  static const String darkText = '#1e293b';
  static const String white = '#ffffff';

  // ================== APP INFO ==================
  static const String appName = 'UpGrade';
  static const String appTagline = 'AI-Powered Study Assistant';

  /// Public hosted privacy page (Firebase Hosting)
  static const String publicPrivacyPolicyPageUrl =
      'https://upgrade-e87b3.web.app/privacy.html';

  /// Encoded in the desktop pairing QR. Opens in the phone browser if the app is not
  /// installed; that page tries `upgrade://pair` then sends the user to the store.
  /// Deploy `frontend/public/pair.html` with Firebase Hosting (same site as privacy).
  static const String pairingQrLandingPageUrl =
      'https://upgrade-e87b3.web.app/pair.html';

  /// Google Play listing — keep in sync with `applicationId` in `android/app/build.gradle.kts`.
  static const String playStoreListingUrl =
      'https://play.google.com/store/apps/details?id=com.example.frontend';

  /// App Store — replace with `https://apps.apple.com/app/idXXXXXXXX` when published.
  static const String appStoreListingUrl =
      'https://apps.apple.com/search?term=UpGrade';

  // ================== ROUTES ==================
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeForgotPassword = '/forgot-password';
  static const String routeGoogleClassroomSync = '/google-classroom-sync';
  static const String routeManualCourses = '/manual-courses';
  static const String routeDevicePairing = '/device-pairing';
  static const String routeOnboarding = '/onboarding';
  /// Shown right after login/register: sync Google Classroom or skip to device pairing.
  static const String routeWelcomeSyncChoice = '/welcome-sync-choice';
  static const String routeHome = '/home';
  static const String routeDailyPlanner = '/daily-planner';

  static const String routeTaskExecution = '/task-execution';
  static const String routeWarnings = '/warnings';
  static const String routeProgress = '/progress';
  static const String routeBurnout = '/burnout';
  static const String routeGroupStudy = '/group-study';
  static const String routeEndOfDay = '/end-of-day';
  static const String routeAIChatbot = '/ai-chatbot';
  static const String routeWeeklySchedule = '/weekly-schedule';
  static const String routePastTasks = '/past-tasks';
  static const String routeMissedTasks = '/missed-tasks';
  static const String routeFirestoreExample = '/firestore-example';
  static const String routeStudyPlan = '/study-plan';
  static const String routeQrScanner = '/qr-scanner';
  static const String routeProfile = '/profile';

  /// In-app full privacy policy text
  static const String routePrivacy = '/privacy-policy';

  static const String routePrivacySettings = '/privacy-settings';
  static const String routeEditProfile = '/edit-profile';
  static const String routeEndSession = '/end-session';

  // Deep link
  static const String deepLinkScheme = 'studyplanner';
  static const String deepLinkOpen = 'studyplanner://open';
}