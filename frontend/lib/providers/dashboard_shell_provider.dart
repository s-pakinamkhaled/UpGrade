import 'package:flutter/material.dart';
import '../core/constants.dart';

/// Shared navigation + sidebar state for [MainNavigationScreen] (IndexedStack tabs + sidebar).
class DashboardShellProvider extends ChangeNotifier {
  /// Routes shown in [MainNavigationScreen]'s [IndexedStack] (not pushed overlays).
  static bool isMainShellTabRoute(String route) {
    switch (route) {
      case AppConstants.routeProgress:
      case AppConstants.routeDailyPlanner:
      case AppConstants.routeAIChatbot:
      case AppConstants.routeStudyPlan:
      case AppConstants.routeGroupStudy:
      case AppConstants.routeWarnings:
      case AppConstants.routeProfile:
      case AppConstants.routeGoogleClassroomSync:
      case AppConstants.routeManualCourses:
        return true;
      default:
        return false;
    }
  }

  String _selectedRoute = AppConstants.routeProgress;
  String _previousRoute = AppConstants.routeProgress;
  /// Wide layout: show full sidebar by default; user can collapse to the narrow rail.
  bool _sidebarExpanded = true;
  /// Shown on [GoogleClassroomSyncScreen] when user opens it from post-login welcome (inside shell).
  bool _googleClassroomFromPostLoginSetup = false;

  String get selectedRoute => _selectedRoute;
  int get currentIndex => _indexForRoute(_selectedRoute);
  bool get sidebarExpanded => _sidebarExpanded;
  bool get googleClassroomFromPostLoginSetup =>
      _googleClassroomFromPostLoginSetup;

  void setGoogleClassroomFromPostLoginSetup(bool value) {
    if (_googleClassroomFromPostLoginSetup == value) return;
    _googleClassroomFromPostLoginSetup = value;
    notifyListeners();
  }

  void selectTab(int index) {
    final targetRoute = _routeForIndex(index);
    if (_selectedRoute == targetRoute) return;
    _selectedRoute = targetRoute;
    notifyListeners();
  }

  /// Updates sidebar highlight and [IndexedStack] tab. Only main tab routes.
  void selectRoute(String route) {
    if (!DashboardShellProvider.isMainShellTabRoute(route)) return;
    if (_selectedRoute == route) return;
    _selectedRoute = route;
    notifyListeners();
  }

  void enterEndSession() {
    _previousRoute = _selectedRoute;
    _selectedRoute = AppConstants.routeEndSession;
    notifyListeners();
  }

  void exitEndSessionContinue() {
    _selectedRoute = _previousRoute;
    notifyListeners();
  }

  void setSidebarExpanded(bool value) {
    if (_sidebarExpanded == value) return;
    _sidebarExpanded = value;
    notifyListeners();
  }

  /// Call on sign-out so the next session starts on Dashboard with the rail collapsed.
  void resetForNewSession() {
    _selectedRoute = AppConstants.routeProgress;
    _previousRoute = AppConstants.routeProgress;
    _sidebarExpanded = false;
    _googleClassroomFromPostLoginSetup = false;
    notifyListeners();
  }

  int _indexForRoute(String route) {
    switch (route) {
      case AppConstants.routeProgress:
        return 0;
      case AppConstants.routeDailyPlanner:
        return 1;
      case AppConstants.routeAIChatbot:
        return 2;
      case AppConstants.routeStudyPlan:
        return 3;
      case AppConstants.routeGroupStudy:
        return 4;
      case AppConstants.routeWarnings:
        return 5;
      case AppConstants.routeProfile:
        return 6;
      case AppConstants.routeGoogleClassroomSync:
        return 7;
      case AppConstants.routeManualCourses:
        return 8;
      case AppConstants.routeEndSession:
        return 9;
      default:
        return 0;
    }
  }

  String _routeForIndex(int index) {
    switch (index) {
      case 0:
        return AppConstants.routeProgress;
      case 1:
        return AppConstants.routeDailyPlanner;
      case 2:
        return AppConstants.routeAIChatbot;
      case 3:
        return AppConstants.routeStudyPlan;
      case 4:
        return AppConstants.routeGroupStudy;
      case 5:
        return AppConstants.routeWarnings;
      case 6:
        return AppConstants.routeProfile;
      case 7:
        return AppConstants.routeGoogleClassroomSync;
      case 8:
        return AppConstants.routeManualCourses;
      case 9:
        return AppConstants.routeEndSession;
      default:
        return AppConstants.routeProgress;
    }
  }
}
