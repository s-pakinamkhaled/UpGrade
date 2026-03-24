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
  final VoidCallback onCollapse;
  /// Highlights a pushed route: My courses, Study Plan, Warnings, Profile, etc.
  final String? highlightRoute;

  const DashboardSidebar({
    super.key,
    required this.currentIndex,
    required this.onSelectTab,
    required this.onNavigateToRoute,
    required this.onEndSession,
    required this.onCollapse,
    this.highlightRoute,
  });

  /// Default width; actual width scales slightly with viewport (see [effectiveWidth]).
  static const double width = 260;
  /// Dark blue to match app theme (aligned with AppTheme.darkSurface).
  static const Color sidebarBackground = Color(0xFF0F172A);
  static const Color navInactive = Color(0xFF9CA3AF);

  static double effectiveWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.24).clamp(220.0, 288.0);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final compactH = mq.height < 720;
    final topPad = compactH ? 12.0 : 24.0;
    final afterLogo = compactH ? 16.0 : 32.0;

    return Container(
      width: effectiveWidth(context),
      color: sidebarBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: topPad),
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: Row(
                children: [
                  const AppLogo.small(),
                  const SizedBox(width: 8),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          AppConstants.appTagline,
                          style: TextStyle(
                            color: navInactive,
                            fontSize: compactH ? 11 : 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white70),
                    tooltip: 'Collapse sidebar',
                    onPressed: onCollapse,
                  ),
                ],
              ),
            ),
            SizedBox(height: afterLogo),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: compactH ? 12 : 24),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _NavItem(
                    icon: Icons.calendar_today_outlined,
                    label: 'Daily Planner',
                    selected: currentIndex == 0,
                    compact: compactH,
                    onTap: () => onSelectTab(0),
                  ),
                  _NavItem(
                    icon: Icons.auto_awesome_outlined,
                    label: 'AI Assistant',
                    selected: currentIndex == 1,
                    compact: compactH,
                    onTap: () => onSelectTab(1),
                  ),
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    selected: currentIndex == 2,
                    compact: compactH,
                    onTap: () => onSelectTab(2),
                  ),
                  _NavItem(
                    icon: Icons.school_outlined,
                    label: 'Study Plan',
                    selected:
                        highlightRoute == AppConstants.routeStudyPlan,
                    compact: compactH,
                    onTap: () => onNavigateToRoute(AppConstants.routeStudyPlan),
                  ),
                  _NavItem(
                    icon: Icons.groups_outlined,
                    label: 'Group Study',
                    selected: currentIndex == 3,
                    compact: compactH,
                    onTap: () => onSelectTab(3),
                  ),
                  _NavItem(
                    icon: Icons.warning_amber_outlined,
                    label: 'Warnings',
                    selected:
                        highlightRoute == AppConstants.routeWarnings,
                    compact: compactH,
                    onTap: () => onNavigateToRoute(AppConstants.routeWarnings),
                  ),
                  _NavItem(
                    icon: Icons.person_outline,
                    label: 'Profile',
                    selected:
                        highlightRoute == AppConstants.routeProfile,
                    compact: compactH,
                    onTap: () => onNavigateToRoute(AppConstants.routeProfile),
                  ),
                  const Divider(color: Color(0xFF374151), height: 24),
                  _NavItem(
                    icon: Icons.qr_code_scanner_outlined,
                    label: 'Device Pairing',
                    selected: false,
                    compact: compactH,
                    onTap: () => onNavigateToRoute(AppConstants.routeQrScanner),
                  ),
                  _NavItem(
                    icon: Icons.class_outlined,
                    label: 'Google Classroom',
                    selected: false,
                    compact: compactH,
                    onTap: () =>
                        onNavigateToRoute(AppConstants.routeGoogleClassroomSync),
                  ),
                  _NavItem(
                    icon: Icons.playlist_add_outlined,
                    label: 'My courses',
                    selected:
                        highlightRoute == AppConstants.routeManualCourses,
                    compact: compactH,
                    onTap: () =>
                        onNavigateToRoute(AppConstants.routeManualCourses),
                  ),
                  _NavItem(
                    icon: Icons.logout,
                    label: 'End Session',
                    selected: false,
                    compact: compactH,
                    isDestructive: true,
                    onTap: onEndSession,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon-only strip when the full sidebar is hidden. Stays visible for every main tab.
class DashboardSidebarCollapsedRail extends StatelessWidget {
  static const double railWidth = 56;

  final int currentIndex;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onExpand;
  final void Function(String route) onNavigateToRoute;
  final VoidCallback onEndSession;
  final String? highlightRoute;

  const DashboardSidebarCollapsedRail({
    super.key,
    required this.currentIndex,
    required this.onSelectTab,
    required this.onExpand,
    required this.onNavigateToRoute,
    required this.onEndSession,
    this.highlightRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DashboardSidebar.sidebarBackground,
      child: SafeArea(
        child: SizedBox(
          width: railWidth,
          child: Column(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                tooltip: 'Expand sidebar',
                onPressed: onExpand,
              ),
              const Divider(color: Color(0xFF374151), height: 1),
              _CollapsedRailNavButton(
                icon: Icons.calendar_today_outlined,
                selectedIcon: Icons.calendar_today,
                selected: currentIndex == 0,
                tooltip: 'Daily Planner',
                onTap: () => onSelectTab(0),
              ),
              _CollapsedRailNavButton(
                icon: Icons.auto_awesome_outlined,
                selectedIcon: Icons.auto_awesome,
                selected: currentIndex == 1,
                tooltip: 'AI Assistant',
                onTap: () => onSelectTab(1),
              ),
              _CollapsedRailNavButton(
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard,
                selected: currentIndex == 2,
                tooltip: 'Dashboard',
                onTap: () => onSelectTab(2),
              ),
              _CollapsedRailNavButton(
                icon: Icons.groups_outlined,
                selectedIcon: Icons.groups,
                selected: currentIndex == 3,
                tooltip: 'Group Study',
                onTap: () => onSelectTab(3),
              ),
              _CollapsedRailNavButton(
                icon: Icons.school_outlined,
                selectedIcon: Icons.school,
                selected: highlightRoute == AppConstants.routeStudyPlan,
                tooltip: 'Study Plan',
                onTap: () =>
                    onNavigateToRoute(AppConstants.routeStudyPlan),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.menu, color: DashboardSidebar.navInactive),
                tooltip: 'Full menu',
                onPressed: onExpand,
              ),
              IconButton(
                icon: Icon(
                  Icons.notifications_outlined,
                  color: highlightRoute == AppConstants.routeWarnings
                      ? Colors.white
                      : DashboardSidebar.navInactive,
                ),
                tooltip: 'Warnings',
                style: highlightRoute == AppConstants.routeWarnings
                    ? IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.12),
                      )
                    : null,
                onPressed: () => onNavigateToRoute(AppConstants.routeWarnings),
              ),
              IconButton(
                icon: Icon(
                  Icons.person_outline,
                  color: highlightRoute == AppConstants.routeProfile
                      ? Colors.white
                      : DashboardSidebar.navInactive,
                ),
                tooltip: 'Profile',
                style: highlightRoute == AppConstants.routeProfile
                    ? IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.12),
                      )
                    : null,
                onPressed: () => onNavigateToRoute(AppConstants.routeProfile),
              ),
              IconButton(
                icon: Icon(
                  Icons.playlist_add_outlined,
                  color: highlightRoute == AppConstants.routeManualCourses
                      ? Colors.white
                      : DashboardSidebar.navInactive,
                ),
                tooltip: 'My courses',
                style: highlightRoute == AppConstants.routeManualCourses
                    ? IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.12),
                      )
                    : null,
                onPressed: () =>
                    onNavigateToRoute(AppConstants.routeManualCourses),
              ),
              const Divider(color: Color(0xFF374151), height: 1),
              IconButton(
                icon: Icon(Icons.logout, color: AppTheme.errorRed.withOpacity(0.9)),
                tooltip: 'End session',
                onPressed: onEndSession,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapsedRailNavButton extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  const _CollapsedRailNavButton({
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : DashboardSidebar.navInactive;
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: selected ? AppTheme.primaryGradient : null,
              ),
              child: Icon(
                selected ? selectedIcon : icon,
                size: 22,
                color: color,
              ),
            ),
          ),
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
  final bool compact;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isDestructive = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? AppTheme.errorRed
        : (selected ? Colors.white : DashboardSidebar.navInactive);
    final vPad = compact ? 6.0 : 12.0;
    final fontSize = compact ? 13.0 : 14.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 2 : 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: vPad),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: selected && !isDestructive
                  ? AppTheme.primaryGradient
                  : null,
            ),
            child: Row(
              children: [
                Icon(icon, size: compact ? 20 : 22, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: fontSize,
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
