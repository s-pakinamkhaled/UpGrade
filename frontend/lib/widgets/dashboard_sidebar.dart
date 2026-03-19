import 'package:flutter/material.dart';
import 'package:upgrade/core/constants.dart';
import 'package:upgrade/core/theme.dart';
import 'package:upgrade/widgets/app_logo.dart';

/// Sidebar for the Progress Dashboard layout (StudyAI-style).
/// Dark blue background to match website colors; nav items with active (blue–purple gradient).
class DashboardSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelectTab;
  final void Function(String route) onNavigateToRoute;
  final VoidCallback onEndSession;

  const DashboardSidebar({
    super.key,
    required this.currentIndex,
    required this.onSelectTab,
    required this.onNavigateToRoute,
    required this.onEndSession,
  });

  static const double width = 260;
  /// Dark blue to match app theme (aligned with AppTheme.darkSurface).
  static const Color sidebarBackground = Color(0xFF0F172A);
  static const Color navInactive = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: sidebarBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const AppLogo.small(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConstants.appName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          AppConstants.appTagline,
                          style: TextStyle(
                            color: navInactive,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _NavItem(
              icon: Icons.calendar_today_outlined,
              label: 'Daily Planner',
              selected: currentIndex == 0,
              onTap: () => onSelectTab(0),
            ),
            _NavItem(
              icon: Icons.auto_awesome_outlined,
              label: 'AI Assistant',
              selected: currentIndex == 1,
              onTap: () => onSelectTab(1),
            ),
            _NavItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              selected: currentIndex == 2,
              onTap: () => onSelectTab(2),
            ),
            _NavItem(
              icon: Icons.school_outlined,
              label: 'Study Plan',
              selected: false,
              onTap: () => onNavigateToRoute(AppConstants.routeStudyPlan),
            ),
            _NavItem(
              icon: Icons.groups_outlined,
              label: 'Group Study',
              selected: currentIndex == 3,
              onTap: () => onSelectTab(3),
            ),
            _NavItem(
              icon: Icons.warning_amber_outlined,
              label: 'Warnings',
              selected: false,
              onTap: () => onNavigateToRoute(AppConstants.routeWarnings),
            ),
            _NavItem(
              icon: Icons.person_outline,
              label: 'Profile',
              selected: false,
              onTap: () => onNavigateToRoute(AppConstants.routeProfile),
            ),
            const Spacer(),
            const Divider(color: Color(0xFF374151), height: 1),
            const SizedBox(height: 8),
            _NavItem(
              icon: Icons.qr_code_scanner_outlined,
              label: 'Device Pairing',
              selected: false,
              onTap: () => onNavigateToRoute(AppConstants.routeQrScanner),
            ),
            _NavItem(
              icon: Icons.class_outlined,
              label: 'Google Classroom',
              selected: false,
              onTap: () => onNavigateToRoute(AppConstants.routeGoogleClassroomSync),
            ),
            _NavItem(
              icon: Icons.logout,
              label: 'End Session',
              selected: false,
              isDestructive: true,
              onTap: onEndSession,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDestructive;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? AppTheme.errorRed
        : (selected ? Colors.white : DashboardSidebar.navInactive);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: selected && !isDestructive
                  ? AppTheme.primaryGradient
                  : null,
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
