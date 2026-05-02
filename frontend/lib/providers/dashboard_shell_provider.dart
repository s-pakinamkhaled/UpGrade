import 'package:flutter/material.dart';
import '../core/constants.dart';

/// Shared navigation + sidebar state for [MainNavigationScreen] and shell-wrapped routes
/// (e.g. Manual Courses on wide layout) so the sidebar stays consistent.
class DashboardShellProvider extends ChangeNotifier {
  String _selectedRoute = AppConstants.routeDailyPlanner;
  String _previousRoute = AppConstants.routeDailyPlanner;
  /// Wide layout: sidebar starts collapsed until the user expands it.
  bool _sidebarExpanded = false;

  String get selectedRoute => _selectedRoute;
  int get currentIndex => _indexForRoute(_selectedRoute);
  bool get sidebarExpanded => _sidebarExpanded;

  void selectTab(int index) {
    final targetRoute = _routeForIndex(index);
    if (_selectedRoute == targetRoute) return;
    _selectedRoute = targetRoute;
    notifyListeners();
  }

  void selectRoute(String route) {
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

  /// Call on sign-out so the next session starts on Planner with the rail closed.
  void resetForNewSession() {
    _selectedRoute = AppConstants.routeDailyPlanner;
    _previousRoute = AppConstants.routeDailyPlanner;
    _sidebarExpanded = false;
    notifyListeners();
  }

  int _indexForRoute(String route) {
    switch (route) {
      case AppConstants.routeAIChatbot:
        return 1;
      case AppConstants.routeProgress:
        return 2;
      case AppConstants.routeGroupStudy:
        return 3;
      case AppConstants.routeEndSession:
        return 4;
      case AppConstants.routeDailyPlanner:
      default:
        return 0;
    }
  }

  String _routeForIndex(int index) {
    switch (index) {
      case 1:
        return AppConstants.routeAIChatbot;
      case 2:
        return AppConstants.routeProgress;
      case 3:
        return AppConstants.routeGroupStudy;
      case 4:
        return AppConstants.routeEndSession;
      case 0:
      default:
        return AppConstants.routeDailyPlanner;
    }
  }
}
