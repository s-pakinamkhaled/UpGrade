class AppConstants {
  // ================== COLORS ==================
  static const String primaryBlue = '#3b82f6';
  static const String secondaryPurple = '#8b5cf6';
  static const String darkText = '#1e293b';
  static const String white = '#ffffff';

  // ================== APP INFO ==================
  static const String appName = 'UpGrade';
  static const String appTagline = 'AI-Powered Study Assistant';

  // ================== ROUTES ==================
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeForgotPassword = '/forgot-password';
  static const String routeGoogleClassroomSync =
      '/google-classroom-sync';
  static const String routeManualCourses = '/manual-courses';
  static const String routeDevicePairing = '/device-pairing';
  static const String routeOnboarding = '/onboarding';
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
  static const String routePrivacySettings = '/privacy-settings';
  static const String routeEditProfile = '/edit-profile';
  static const String routeEndSession = '/end-session';

  // Deep link (لما الويب يعرض QR أو زر Open App → يفتح التطبيق)
  static const String deepLinkScheme = 'studyplanner';
  static const String deepLinkOpen = 'studyplanner://open';
}
