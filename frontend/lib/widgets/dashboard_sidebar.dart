import 'package:flutter/material.dart';
import 'package:upgrade/core/constants.dart';
import 'package:upgrade/core/theme.dart';
import 'package:upgrade/widgets/app_logo.dart';

/// Sidebar for the Progress Dashboard layout (StudyAI-style).
<<<<<<< HEAD
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
=======
/// Light background with active blue-purple item matching the reference UI.
class DashboardSidebar extends StatelessWidget {
  final String selectedRoute;
  final void Function(String route) onSelectRoute;
  final void Function(String route) onNavigateToRoute;
  final VoidCallback onEndSession;
  final VoidCallback onCollapse;

  const DashboardSidebar({
    super.key,
    required this.selectedRoute,
    required this.onSelectRoute,
    required this.onNavigateToRoute,
    required this.onEndSession,
    required this.onCollapse,
>>>>>>> origin/continue
  });

  /// Default width; actual width scales slightly with viewport (see [effectiveWidth]).
  static const double width = 260;
<<<<<<< HEAD
  /// Dark blue to match app theme (aligned with AppTheme.darkSurface).
  static const Color sidebarBackground = Color(0xFF0F172A);
  static const Color navInactive = Color(0xFF9CA3AF);
=======
  static const Color sidebarBackground = Color(0xFFF8FAFC);
  /// Inactive nav label/icon on **light** sidebar (higher contrast than slate-400).
  static const Color navInactiveLight = Color(0xFF475569);
  /// Inactive nav on **dark** sidebar.
  static const Color navInactiveDark = Color(0xFF9CA3AF);

  static Color navInactiveFor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? navInactiveDark
        : navInactiveLight;
  }
>>>>>>> origin/continue

  static double effectiveWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.24).clamp(220.0, 288.0);
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
=======
    final isDark = Theme.of(context).brightness == Brightness.dark;
>>>>>>> origin/continue
    final mq = MediaQuery.sizeOf(context);
    final compactH = mq.height < 720;
    final topPad = compactH ? 12.0 : 24.0;
    final afterLogo = compactH ? 16.0 : 32.0;

<<<<<<< HEAD
    return Container(
      width: effectiveWidth(context),
      color: sidebarBackground,
=======
    final activeMenuKey = _activeMenuKeyForRoute(selectedRoute);

    return Container(
      width: effectiveWidth(context),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : sidebarBackground,
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
>>>>>>> origin/continue
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
<<<<<<< HEAD
                          style: const TextStyle(
                            color: Colors.white,
=======
                          style: TextStyle(
                            color: isDark ? Colors.white : AppTheme.darkText,
>>>>>>> origin/continue
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          AppConstants.appTagline,
                          style: TextStyle(
<<<<<<< HEAD
                            color: navInactive,
=======
                            color: navInactiveFor(context),
>>>>>>> origin/continue
                            fontSize: compactH ? 11 : 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
<<<<<<< HEAD
                    icon: const Icon(Icons.chevron_left, color: Colors.white70),
=======
                    icon: Icon(
                      Icons.chevron_left,
                      color: isDark ? Colors.white70 : AppTheme.darkText,
                    ),
>>>>>>> origin/continue
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
<<<<<<< HEAD
                    selected: currentIndex == 0,
                    compact: compactH,
                    onTap: () => onSelectTab(0),
=======
                    isActive: activeMenuKey == _SidebarMenuKey.dailyPlanner,
                    compact: compactH,
                    onTap: () => onSelectRoute(AppConstants.routeDailyPlanner),
>>>>>>> origin/continue
                  ),
                  _NavItem(
                    icon: Icons.auto_awesome_outlined,
                    label: 'AI Assistant',
<<<<<<< HEAD
                    selected: currentIndex == 1,
                    compact: compactH,
                    onTap: () => onSelectTab(1),
=======
                    isActive: activeMenuKey == _SidebarMenuKey.aiAssistant,
                    compact: compactH,
                    onTap: () => onSelectRoute(AppConstants.routeAIChatbot),
>>>>>>> origin/continue
                  ),
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
<<<<<<< HEAD
                    selected: currentIndex == 2,
                    compact: compactH,
                    onTap: () => onSelectTab(2),
=======
                    isActive: activeMenuKey == _SidebarMenuKey.dashboard,
                    compact: compactH,
                    onTap: () => onSelectRoute(AppConstants.routeProgress),
>>>>>>> origin/continue
                  ),
                  _NavItem(
                    icon: Icons.school_outlined,
                    label: 'Study Plan',
<<<<<<< HEAD
                    selected:
                        highlightRoute == AppConstants.routeStudyPlan,
=======
                    isActive: activeMenuKey == _SidebarMenuKey.studyPlan,
>>>>>>> origin/continue
                    compact: compactH,
                    onTap: () => onNavigateToRoute(AppConstants.routeStudyPlan),
                  ),
                  _NavItem(
                    icon: Icons.groups_outlined,
                    label: 'Group Study',
<<<<<<< HEAD
                    selected: currentIndex == 3,
                    compact: compactH,
                    onTap: () => onSelectTab(3),
=======
                    isActive: activeMenuKey == _SidebarMenuKey.groupStudy,
                    compact: compactH,
                    onTap: () => onSelectRoute(AppConstants.routeGroupStudy),
>>>>>>> origin/continue
                  ),
                  _NavItem(
                    icon: Icons.warning_amber_outlined,
                    label: 'Warnings',
<<<<<<< HEAD
                    selected:
                        highlightRoute == AppConstants.routeWarnings,
=======
                    isActive: activeMenuKey == _SidebarMenuKey.warnings,
>>>>>>> origin/continue
                    compact: compactH,
                    onTap: () => onNavigateToRoute(AppConstants.routeWarnings),
                  ),
                  _NavItem(
                    icon: Icons.person_outline,
                    label: 'Profile',
<<<<<<< HEAD
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
=======
                    isActive: activeMenuKey == _SidebarMenuKey.profile,
                    compact: compactH,
                    onTap: () => onNavigateToRoute(AppConstants.routeProfile),
                  ),
                  Divider(
                    color:
                        isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
                    height: 24,
                  ),
                  _NavItem(
                    icon: Icons.qr_code_scanner_outlined,
                    label: 'Device Pairing',
                    isActive: false,
>>>>>>> origin/continue
                    compact: compactH,
                    onTap: () => onNavigateToRoute(AppConstants.routeQrScanner),
                  ),
                  _NavItem(
                    icon: Icons.class_outlined,
                    label: 'Google Classroom',
<<<<<<< HEAD
                    selected: false,
=======
                    isActive: false,
>>>>>>> origin/continue
                    compact: compactH,
                    onTap: () =>
                        onNavigateToRoute(AppConstants.routeGoogleClassroomSync),
                  ),
                  _NavItem(
                    icon: Icons.playlist_add_outlined,
                    label: 'My courses',
<<<<<<< HEAD
                    selected:
                        highlightRoute == AppConstants.routeManualCourses,
=======
                    isActive: activeMenuKey == _SidebarMenuKey.myCourses,
>>>>>>> origin/continue
                    compact: compactH,
                    onTap: () =>
                        onNavigateToRoute(AppConstants.routeManualCourses),
                  ),
                  _NavItem(
                    icon: Icons.logout,
                    label: 'End Session',
<<<<<<< HEAD
                    selected: false,
=======
                    isActive: false,
>>>>>>> origin/continue
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

<<<<<<< HEAD
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
=======
  final String selectedRoute;
  final void Function(String route) onSelectRoute;
  final VoidCallback onExpand;
  final void Function(String route) onNavigateToRoute;
  final VoidCallback onEndSession;

  const DashboardSidebarCollapsedRail({
    super.key,
    required this.selectedRoute,
    required this.onSelectRoute,
    required this.onExpand,
    required this.onNavigateToRoute,
    required this.onEndSession,
>>>>>>> origin/continue
  });

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    return Material(
      color: DashboardSidebar.sidebarBackground,
=======
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeMenuKey = _activeMenuKeyForRoute(selectedRoute);
    return Material(
      color: isDark ? const Color(0xFF0F172A) : DashboardSidebar.sidebarBackground,
>>>>>>> origin/continue
      child: SafeArea(
        child: SizedBox(
          width: railWidth,
          child: Column(
            children: [
              IconButton(
<<<<<<< HEAD
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
=======
                icon: Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.white70 : AppTheme.darkText,
                ),
                tooltip: 'Expand sidebar',
                onPressed: onExpand,
              ),
              Divider(
                color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
                height: 1,
              ),
              _CollapsedRailNavButton(
                icon: Icons.calendar_today_outlined,
                selectedIcon: Icons.calendar_today,
                isActive: activeMenuKey == _SidebarMenuKey.dailyPlanner,
                tooltip: 'Daily Planner',
                onTap: () => onSelectRoute(AppConstants.routeDailyPlanner),
>>>>>>> origin/continue
              ),
              _CollapsedRailNavButton(
                icon: Icons.auto_awesome_outlined,
                selectedIcon: Icons.auto_awesome,
<<<<<<< HEAD
                selected: currentIndex == 1,
                tooltip: 'AI Assistant',
                onTap: () => onSelectTab(1),
=======
                isActive: activeMenuKey == _SidebarMenuKey.aiAssistant,
                tooltip: 'AI Assistant',
                onTap: () => onSelectRoute(AppConstants.routeAIChatbot),
>>>>>>> origin/continue
              ),
              _CollapsedRailNavButton(
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard,
<<<<<<< HEAD
                selected: currentIndex == 2,
                tooltip: 'Dashboard',
                onTap: () => onSelectTab(2),
=======
                isActive: activeMenuKey == _SidebarMenuKey.dashboard,
                tooltip: 'Dashboard',
                onTap: () => onSelectRoute(AppConstants.routeProgress),
>>>>>>> origin/continue
              ),
              _CollapsedRailNavButton(
                icon: Icons.groups_outlined,
                selectedIcon: Icons.groups,
<<<<<<< HEAD
                selected: currentIndex == 3,
                tooltip: 'Group Study',
                onTap: () => onSelectTab(3),
=======
                isActive: activeMenuKey == _SidebarMenuKey.groupStudy,
                tooltip: 'Group Study',
                onTap: () => onSelectRoute(AppConstants.routeGroupStudy),
>>>>>>> origin/continue
              ),
              _CollapsedRailNavButton(
                icon: Icons.school_outlined,
                selectedIcon: Icons.school,
<<<<<<< HEAD
                selected: highlightRoute == AppConstants.routeStudyPlan,
=======
                isActive: activeMenuKey == _SidebarMenuKey.studyPlan,
>>>>>>> origin/continue
                tooltip: 'Study Plan',
                onTap: () =>
                    onNavigateToRoute(AppConstants.routeStudyPlan),
              ),
              const Spacer(),
              IconButton(
<<<<<<< HEAD
                icon: Icon(Icons.menu, color: DashboardSidebar.navInactive),
=======
                icon: Icon(Icons.menu, color: DashboardSidebar.navInactiveFor(context)),
>>>>>>> origin/continue
                tooltip: 'Full menu',
                onPressed: onExpand,
              ),
              IconButton(
                icon: Icon(
                  Icons.notifications_outlined,
<<<<<<< HEAD
                  color: highlightRoute == AppConstants.routeWarnings
                      ? Colors.white
                      : DashboardSidebar.navInactive,
                ),
                tooltip: 'Warnings',
                style: highlightRoute == AppConstants.routeWarnings
                    ? IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.12),
=======
                  color: activeMenuKey == _SidebarMenuKey.warnings
                      ? AppTheme.primaryBlue
                      : DashboardSidebar.navInactiveFor(context),
                ),
                tooltip: 'Warnings',
                style: activeMenuKey == _SidebarMenuKey.warnings
                    ? IconButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue.withOpacity(0.12),
>>>>>>> origin/continue
                      )
                    : null,
                onPressed: () => onNavigateToRoute(AppConstants.routeWarnings),
              ),
              IconButton(
                icon: Icon(
                  Icons.person_outline,
<<<<<<< HEAD
                  color: highlightRoute == AppConstants.routeProfile
                      ? Colors.white
                      : DashboardSidebar.navInactive,
                ),
                tooltip: 'Profile',
                style: highlightRoute == AppConstants.routeProfile
                    ? IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.12),
=======
                  color: activeMenuKey == _SidebarMenuKey.profile
                      ? AppTheme.primaryBlue
                      : DashboardSidebar.navInactiveFor(context),
                ),
                tooltip: 'Profile',
                style: activeMenuKey == _SidebarMenuKey.profile
                    ? IconButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue.withOpacity(0.12),
>>>>>>> origin/continue
                      )
                    : null,
                onPressed: () => onNavigateToRoute(AppConstants.routeProfile),
              ),
              IconButton(
                icon: Icon(
                  Icons.playlist_add_outlined,
<<<<<<< HEAD
                  color: highlightRoute == AppConstants.routeManualCourses
                      ? Colors.white
                      : DashboardSidebar.navInactive,
                ),
                tooltip: 'My courses',
                style: highlightRoute == AppConstants.routeManualCourses
                    ? IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.12),
=======
                  color: activeMenuKey == _SidebarMenuKey.myCourses
                      ? AppTheme.primaryBlue
                      : DashboardSidebar.navInactiveFor(context),
                ),
                tooltip: 'My courses',
                style: activeMenuKey == _SidebarMenuKey.myCourses
                    ? IconButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue.withOpacity(0.12),
>>>>>>> origin/continue
                      )
                    : null,
                onPressed: () =>
                    onNavigateToRoute(AppConstants.routeManualCourses),
              ),
<<<<<<< HEAD
              const Divider(color: Color(0xFF374151), height: 1),
=======
              Divider(
                color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
                height: 1,
              ),
>>>>>>> origin/continue
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
<<<<<<< HEAD
  final bool selected;
=======
  final bool isActive;
>>>>>>> origin/continue
  final String tooltip;
  final VoidCallback onTap;

  const _CollapsedRailNavButton({
    required this.icon,
    required this.selectedIcon,
<<<<<<< HEAD
    required this.selected,
=======
    required this.isActive,
>>>>>>> origin/continue
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final color = selected ? Colors.white : DashboardSidebar.navInactive;
=======
    final color = isActive
        ? Colors.white
        : DashboardSidebar.navInactiveFor(context);
>>>>>>> origin/continue
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
<<<<<<< HEAD
=======
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            highlightColor: Colors.transparent,
>>>>>>> origin/continue
            child: Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
<<<<<<< HEAD
                gradient: selected ? AppTheme.primaryGradient : null,
              ),
              child: Icon(
                selected ? selectedIcon : icon,
=======
                gradient: isActive ? AppTheme.primaryGradient : null,
                color: isActive ? null : const Color(0x00000000),
              ),
              child: Icon(
                isActive ? selectedIcon : icon,
>>>>>>> origin/continue
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
<<<<<<< HEAD
  final bool selected;
=======
  final bool isActive;
>>>>>>> origin/continue
  final VoidCallback onTap;
  final bool isDestructive;
  final bool compact;

  const _NavItem({
    required this.icon,
    required this.label,
<<<<<<< HEAD
    required this.selected,
=======
    required this.isActive,
>>>>>>> origin/continue
    required this.onTap,
    this.isDestructive = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? AppTheme.errorRed
<<<<<<< HEAD
        : (selected ? Colors.white : DashboardSidebar.navInactive);
=======
        : (isActive
            ? Colors.white
            : DashboardSidebar.navInactiveFor(context));
>>>>>>> origin/continue
    final vPad = compact ? 6.0 : 12.0;
    final fontSize = compact ? 13.0 : 14.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 2 : 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
<<<<<<< HEAD
=======
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          highlightColor: Colors.transparent,
>>>>>>> origin/continue
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: vPad),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
<<<<<<< HEAD
              gradient: selected && !isDestructive
                  ? AppTheme.primaryGradient
                  : null,
=======
              gradient: isActive && !isDestructive
                  ? AppTheme.primaryGradient
                  : null,
              color: isActive || isDestructive
                  ? null
                  : const Color(0x00000000),
>>>>>>> origin/continue
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
<<<<<<< HEAD
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
=======
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
>>>>>>> origin/continue
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
<<<<<<< HEAD
=======

enum _SidebarMenuKey {
  dailyPlanner,
  aiAssistant,
  dashboard,
  studyPlan,
  groupStudy,
  warnings,
  profile,
  myCourses,
}

_SidebarMenuKey? _activeMenuKeyForRoute(String route) {
  switch (route) {
    case AppConstants.routeDailyPlanner:
      return _SidebarMenuKey.dailyPlanner;
    case AppConstants.routeAIChatbot:
      return _SidebarMenuKey.aiAssistant;
    case AppConstants.routeProgress:
      return _SidebarMenuKey.dashboard;
    case AppConstants.routeStudyPlan:
      return _SidebarMenuKey.studyPlan;
    case AppConstants.routeGroupStudy:
      return _SidebarMenuKey.groupStudy;
    case AppConstants.routeWarnings:
      return _SidebarMenuKey.warnings;
    case AppConstants.routeProfile:
    case AppConstants.routeEditProfile:
    case AppConstants.routePrivacySettings:
      return _SidebarMenuKey.profile;
    case AppConstants.routeManualCourses:
      return _SidebarMenuKey.myCourses;
    default:
      return null;
  }
}
>>>>>>> origin/continue
