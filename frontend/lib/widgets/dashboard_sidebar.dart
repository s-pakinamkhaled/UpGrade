import 'package:flutter/material.dart';
import 'package:upgrade/core/constants.dart';
import 'package:upgrade/core/theme.dart';
import 'package:upgrade/widgets/app_logo.dart';

/// Sidebar for the Progress Dashboard layout (StudyAI-style).
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
  });

  /// Default width; actual width scales slightly with viewport (see [effectiveWidth]).
  static const double width = 260;
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

  static double effectiveWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.24).clamp(220.0, 288.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.sizeOf(context);
    final compactH = mq.height < 720;
    final topPad = compactH ? 12.0 : 24.0;
    final afterLogo = compactH ? 16.0 : 32.0;

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
                          style: TextStyle(
                            color: isDark ? Colors.white : AppTheme.darkText,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          AppConstants.appTagline,
                          style: TextStyle(
                            color: navInactiveFor(context),
                            fontSize: compactH ? 11 : 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: isDark ? Colors.white70 : AppTheme.darkText,
                    ),
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
                    isActive: activeMenuKey == _SidebarMenuKey.dailyPlanner,
                    compact: compactH,
                    onTap: () => onSelectRoute(AppConstants.routeDailyPlanner),
                  ),
                  _NavItem(
                    icon: Icons.auto_awesome_outlined,
                    label: 'AI Assistant',
                    isActive: activeMenuKey == _SidebarMenuKey.aiAssistant,
                    compact: compactH,
                    onTap: () => onSelectRoute(AppConstants.routeAIChatbot),
                  ),
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    isActive: activeMenuKey == _SidebarMenuKey.dashboard,
                    compact: compactH,
                    onTap: () => onSelectRoute(AppConstants.routeProgress),
                  ),
                  _NavItem(
                    icon: Icons.school_outlined,
                    label: 'Study Plan',
                    isActive: activeMenuKey == _SidebarMenuKey.studyPlan,
                    compact: compactH,
                    onTap: () => onNavigateToRoute(AppConstants.routeStudyPlan),
                  ),
                  _NavItem(
                    icon: Icons.groups_outlined,
                    label: 'Group Study',
                    isActive: activeMenuKey == _SidebarMenuKey.groupStudy,
                    compact: compactH,
                    onTap: () => onSelectRoute(AppConstants.routeGroupStudy),
                  ),
                  _NavItem(
                    icon: Icons.warning_amber_outlined,
                    label: 'Warnings',
                    isActive: activeMenuKey == _SidebarMenuKey.warnings,
                    compact: compactH,
                    onTap: () => onNavigateToRoute(AppConstants.routeWarnings),
                  ),
                  _NavItem(
                    icon: Icons.person_outline,
                    label: 'Profile',
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
                    compact: compactH,
                    onTap: () => onNavigateToRoute(AppConstants.routeQrScanner),
                  ),
                  _NavItem(
                    icon: Icons.class_outlined,
                    label: 'Google Classroom',
                    isActive: false,
                    compact: compactH,
                    onTap: () =>
                        onNavigateToRoute(AppConstants.routeGoogleClassroomSync),
                  ),
                  _NavItem(
                    icon: Icons.playlist_add_outlined,
                    label: 'My courses',
                    isActive: activeMenuKey == _SidebarMenuKey.myCourses,
                    compact: compactH,
                    onTap: () =>
                        onNavigateToRoute(AppConstants.routeManualCourses),
                  ),
                  _NavItem(
                    icon: Icons.logout,
                    label: 'End Session',
                    isActive: false,
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
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeMenuKey = _activeMenuKeyForRoute(selectedRoute);
    return Material(
      color: isDark ? const Color(0xFF0F172A) : DashboardSidebar.sidebarBackground,
      child: SafeArea(
        child: SizedBox(
          width: railWidth,
          child: Column(
            children: [
              IconButton(
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
              ),
              _CollapsedRailNavButton(
                icon: Icons.auto_awesome_outlined,
                selectedIcon: Icons.auto_awesome,
                isActive: activeMenuKey == _SidebarMenuKey.aiAssistant,
                tooltip: 'AI Assistant',
                onTap: () => onSelectRoute(AppConstants.routeAIChatbot),
              ),
              _CollapsedRailNavButton(
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard,
                isActive: activeMenuKey == _SidebarMenuKey.dashboard,
                tooltip: 'Dashboard',
                onTap: () => onSelectRoute(AppConstants.routeProgress),
              ),
              _CollapsedRailNavButton(
                icon: Icons.groups_outlined,
                selectedIcon: Icons.groups,
                isActive: activeMenuKey == _SidebarMenuKey.groupStudy,
                tooltip: 'Group Study',
                onTap: () => onSelectRoute(AppConstants.routeGroupStudy),
              ),
              _CollapsedRailNavButton(
                icon: Icons.school_outlined,
                selectedIcon: Icons.school,
                isActive: activeMenuKey == _SidebarMenuKey.studyPlan,
                tooltip: 'Study Plan',
                onTap: () =>
                    onNavigateToRoute(AppConstants.routeStudyPlan),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.menu, color: DashboardSidebar.navInactiveFor(context)),
                tooltip: 'Full menu',
                onPressed: onExpand,
              ),
              IconButton(
                icon: Icon(
                  Icons.notifications_outlined,
                  color: activeMenuKey == _SidebarMenuKey.warnings
                      ? AppTheme.primaryBlue
                      : DashboardSidebar.navInactiveFor(context),
                ),
                tooltip: 'Warnings',
                style: activeMenuKey == _SidebarMenuKey.warnings
                    ? IconButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue.withOpacity(0.12),
                      )
                    : null,
                onPressed: () => onNavigateToRoute(AppConstants.routeWarnings),
              ),
              IconButton(
                icon: Icon(
                  Icons.person_outline,
                  color: activeMenuKey == _SidebarMenuKey.profile
                      ? AppTheme.primaryBlue
                      : DashboardSidebar.navInactiveFor(context),
                ),
                tooltip: 'Profile',
                style: activeMenuKey == _SidebarMenuKey.profile
                    ? IconButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue.withOpacity(0.12),
                      )
                    : null,
                onPressed: () => onNavigateToRoute(AppConstants.routeProfile),
              ),
              IconButton(
                icon: Icon(
                  Icons.playlist_add_outlined,
                  color: activeMenuKey == _SidebarMenuKey.myCourses
                      ? AppTheme.primaryBlue
                      : DashboardSidebar.navInactiveFor(context),
                ),
                tooltip: 'My courses',
                style: activeMenuKey == _SidebarMenuKey.myCourses
                    ? IconButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue.withOpacity(0.12),
                      )
                    : null,
                onPressed: () =>
                    onNavigateToRoute(AppConstants.routeManualCourses),
              ),
              Divider(
                color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
                height: 1,
              ),
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
  final bool isActive;
  final String tooltip;
  final VoidCallback onTap;

  const _CollapsedRailNavButton({
    required this.icon,
    required this.selectedIcon,
    required this.isActive,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? Colors.white
        : DashboardSidebar.navInactiveFor(context);
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: isActive ? AppTheme.primaryGradient : null,
                color: isActive ? null : const Color(0x00000000),
              ),
              child: Icon(
                isActive ? selectedIcon : icon,
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
  final bool isActive;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool compact;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isDestructive = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? AppTheme.errorRed
        : (isActive
            ? Colors.white
            : DashboardSidebar.navInactiveFor(context));
    final vPad = compact ? 6.0 : 12.0;
    final fontSize = compact ? 13.0 : 14.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 2 : 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: vPad),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: isActive && !isDestructive
                  ? AppTheme.primaryGradient
                  : null,
              color: isActive || isDestructive
                  ? null
                  : const Color(0x00000000),
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
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
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
