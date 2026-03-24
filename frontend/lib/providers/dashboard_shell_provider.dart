import 'package:flutter/material.dart';

/// Shared navigation + sidebar state for [MainNavigationScreen] and shell-wrapped routes
/// (e.g. Manual Courses on wide layout) so the sidebar stays consistent.
class DashboardShellProvider extends ChangeNotifier {
  int _currentIndex = 0;
  int _previousIndex = 0;
  /// Wide layout: sidebar starts collapsed until the user expands it.
  bool _sidebarExpanded = false;

  int get currentIndex => _currentIndex;
  bool get sidebarExpanded => _sidebarExpanded;

  void selectTab(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }

  void enterEndSession() {
    _previousIndex = _currentIndex;
    _currentIndex = 4;
    notifyListeners();
  }

  void exitEndSessionContinue() {
    _currentIndex = _previousIndex;
    notifyListeners();
  }

  void setSidebarExpanded(bool value) {
    if (_sidebarExpanded == value) return;
    _sidebarExpanded = value;
    notifyListeners();
  }

  /// Call on sign-out so the next session starts on Planner with the rail closed.
  void resetForNewSession() {
    _currentIndex = 0;
    _previousIndex = 0;
    _sidebarExpanded = false;
    notifyListeners();
  }
}
