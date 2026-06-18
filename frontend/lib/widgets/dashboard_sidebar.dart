import 'package:flutter/material.dart';
import 'package:upgrade/core/constants.dart';
import 'package:upgrade/core/theme.dart';
import 'package:upgrade/widgets/app_logo.dart';
import 'package:upgrade/widgets/notification_bell_button.dart';
import 'package:upgrade/widgets/sidebar_rail_icon.dart';

/// Sidebar for the Progress Dashboard layout (StudyAI-style).
/// Light background with active blue-purple item matching the reference UI.
class DashboardSidebar extends StatelessWidget {
  final String selectedRoute;
  /// Main [IndexedStack] tabs only — [DashboardShellProvider.selectRoute].
  final void Function(String route) onSelectShellRoute;
  /// e.g. QR scanner — [Navigator.pushNamed].
  final void Function(String route) onPushAuxiliaryRoute;
  final VoidCallback onEndSession;
  final VoidCallback onCollapse;

  const DashboardSidebar({
    super.key,
    required this.selectedRoute,
    required this.onSelectShellRoute,
    required this.onPushAuxiliaryRoute,
    required this.onEndSession,
    required this.onCollapse,
  });

  /// Expanded sidebar width — fixed so shell layout stays stable during animation.
  static const double width = 260;
  static const Color sidebarBackground = Color(0xFFF8FAFC);
  /// Inactive nav label/icon on **light** sidebar (higher contrast than slate-400).
  static const Color navInactiveLight = Color(0xFF475569);
  /// Inactive nav on **dark** sidebar.
  static const Color navInactiveDark = Color(0xFF9CA3AF);

  static Color navInactiveFor(BuildContext context) {
    return DashboardSidebarRailMetrics.navInactiveFor(context);
  }

  static double effectiveWidth(BuildContext context) => width;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.sizeOf(context);
    final compactH = mq.height < 720;
    final topPad = compactH ? 12.0 : 24.0;
    final afterLogo = compactH ? 16.0 : 32.0;

    final activeMenuKey = _activeMenuKeyForRoute(selectedRoute);

    return DecoratedBox(
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
              padding: const EdgeInsets.only(left: 12, right: 8),
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
                          maxLines: 1,
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
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: onCollapse,
                  ),
                  const NotificationBellButton(),
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
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    isActive: activeMenuKey == _SidebarMenuKey.dashboard,
                    compact: compactH,
                    onTap: () => onSelectShellRoute(AppConstants.routeProgress),
                  ),
                  _NavItem(
                    icon: Icons.calendar_today_outlined,
                    label: 'My Tasks',
                    isActive: activeMenuKey == _SidebarMenuKey.dailyPlanner,
                    compact: compactH,
                    onTap: () => onSelectShellRoute(AppConstants.routeDailyPlanner),
                  ),
                  _NavItem(
                    icon: Icons.auto_awesome_outlined,
                    label: 'AI Assistant',
                    isActive: activeMenuKey == _SidebarMenuKey.aiAssistant,
                    compact: compactH,
                    onTap: () => onSelectShellRoute(AppConstants.routeAIChatbot),
                  ),
                  _NavItem(
                    icon: Icons.school_outlined,
                    label: 'Study Plan',
                    isActive: activeMenuKey == _SidebarMenuKey.studyPlan,
                    compact: compactH,
                    onTap: () => onSelectShellRoute(AppConstants.routeStudyPlan),
                  ),
                  _NavItem(
                    icon: Icons.groups_outlined,
                    label: 'Study Group',
                    isActive: activeMenuKey == _SidebarMenuKey.groupStudy,
                    compact: compactH,
                    onTap: () => onSelectShellRoute(AppConstants.routeGroupStudy),
                  ),
                  _NavItem(
                    icon: Icons.warning_amber_outlined,
                    label: 'Warnings',
                    isActive: activeMenuKey == _SidebarMenuKey.warnings,
                    compact: compactH,
                    onTap: () => onSelectShellRoute(AppConstants.routeWarnings),
                  ),
                  _NavItem(
                    icon: Icons.person_outline,
                    label: 'Profile',
                    isActive: activeMenuKey == _SidebarMenuKey.profile,
                    compact: compactH,
                    onTap: () => onSelectShellRoute(AppConstants.routeProfile),
                  ),
                  Divider(
                    color:
                        isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
                    height: 24,
                  ),
                  _NavItem(
                    icon: Icons.settings_outlined,
                    label: 'Privacy Settings',
                    isActive: activeMenuKey == _SidebarMenuKey.privacySettings,
                    compact: compactH,
                    onTap: () => onPushAuxiliaryRoute(
                      AppConstants.routePrivacySettings,
                    ),
                  ),
                  _NavItem(
                    icon: Icons.qr_code_scanner_outlined,
                    label: 'Device Pairing',
                    isActive: false,
                    compact: compactH,
                    onTap: () => onPushAuxiliaryRoute(
                        AppConstants.devicePairingEntryRouteFor(context),
                      ),
                  ),
                  _NavItem(
                    icon: Icons.class_outlined,
                    label: 'Google Classroom',
                    isActive: activeMenuKey == _SidebarMenuKey.googleClassroom,
                    compact: compactH,
                    onTap: () => onSelectShellRoute(
                        AppConstants.routeGoogleClassroomSync,
                      ),
                  ),
                  _NavItem(
                    icon: Icons.playlist_add_outlined,
                    label: 'My courses',
                    isActive: activeMenuKey == _SidebarMenuKey.myCourses,
                    compact: compactH,
                    onTap: () =>
                        onSelectShellRoute(AppConstants.routeManualCourses),
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
  static const double railWidth = DashboardSidebarRailMetrics.width;

  final String selectedRoute;
  final VoidCallback onExpand;
  final void Function(String route) onSelectShellRoute;
  final void Function(String route) onPushAuxiliaryRoute;
  final VoidCallback onEndSession;

  const DashboardSidebarCollapsedRail({
    super.key,
    required this.selectedRoute,
    required this.onExpand,
    required this.onSelectShellRoute,
    required this.onPushAuxiliaryRoute,
    required this.onEndSession,
  });

  List<_SidebarRailDestination> get _primaryDestinations => const [
        _SidebarRailDestination(
          menuKey: _SidebarMenuKey.dashboard,
          route: AppConstants.routeProgress,
          tooltip: 'Dashboard',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
        ),
        _SidebarRailDestination(
          menuKey: _SidebarMenuKey.dailyPlanner,
          route: AppConstants.routeDailyPlanner,
          tooltip: 'My Tasks',
          icon: Icons.calendar_today_outlined,
          selectedIcon: Icons.calendar_today,
        ),
        _SidebarRailDestination(
          menuKey: _SidebarMenuKey.aiAssistant,
          route: AppConstants.routeAIChatbot,
          tooltip: 'AI Assistant',
          icon: Icons.auto_awesome_outlined,
          selectedIcon: Icons.auto_awesome,
        ),
        _SidebarRailDestination(
          menuKey: _SidebarMenuKey.groupStudy,
          route: AppConstants.routeGroupStudy,
          tooltip: 'Study Group',
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups,
        ),
        _SidebarRailDestination(
          menuKey: _SidebarMenuKey.studyPlan,
          route: AppConstants.routeStudyPlan,
          tooltip: 'Study Plan',
          icon: Icons.school_outlined,
          selectedIcon: Icons.school,
        ),
        _SidebarRailDestination(
          menuKey: _SidebarMenuKey.warnings,
          route: AppConstants.routeWarnings,
          tooltip: 'Warnings',
          icon: Icons.warning_amber_outlined,
          selectedIcon: Icons.warning_amber_rounded,
        ),
      ];

  Future<void> _openMoreMenu(BuildContext context) async {
    final selected = await showMenu<_RailMoreAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        DashboardSidebarRailMetrics.width + 8,
        MediaQuery.paddingOf(context).top + 120,
        16,
        0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: const [
        PopupMenuItem(
          value: _RailMoreAction.googleClassroom,
          child: ListTile(
            leading: Icon(Icons.class_outlined),
            title: Text('Google Classroom'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        PopupMenuItem(
          value: _RailMoreAction.myCourses,
          child: ListTile(
            leading: Icon(Icons.playlist_add_outlined),
            title: Text('My courses'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        PopupMenuItem(
          value: _RailMoreAction.privacySettings,
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Privacy Settings'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        PopupMenuItem(
          value: _RailMoreAction.devicePairing,
          child: ListTile(
            leading: Icon(Icons.qr_code_scanner_outlined),
            title: Text('Device Pairing'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _RailMoreAction.expandSidebar,
          child: ListTile(
            leading: Icon(Icons.view_sidebar_outlined),
            title: Text('Expand sidebar'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );

    if (!context.mounted || selected == null) return;

    switch (selected) {
      case _RailMoreAction.googleClassroom:
        onSelectShellRoute(AppConstants.routeGoogleClassroomSync);
      case _RailMoreAction.myCourses:
        onSelectShellRoute(AppConstants.routeManualCourses);
      case _RailMoreAction.privacySettings:
        onPushAuxiliaryRoute(AppConstants.routePrivacySettings);
      case _RailMoreAction.devicePairing:
        onPushAuxiliaryRoute(AppConstants.devicePairingEntryRouteFor(context));
      case _RailMoreAction.expandSidebar:
        onExpand();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeMenuKey = _activeMenuKeyForRoute(selectedRoute);

    return Material(
      color: isDark ? const Color(0xFF0F172A) : DashboardSidebar.sidebarBackground,
      child: DecoratedBox(
        decoration: BoxDecoration(
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
                Padding(
                  padding: DashboardSidebarRailMetrics.headerPadding,
                  child: SidebarRailIcon(
                    tooltip: 'Expand sidebar',
                    icon: Icons.chevron_right_rounded,
                    onTap: onExpand,
                  ),
                ),
                const SidebarRailDivider(compact: true),
                Expanded(
                  child: ListView(
                    padding: DashboardSidebarRailMetrics.navPadding,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    children: [
                      for (final destination in _primaryDestinations)
                        SidebarRailIcon(
                          tooltip: destination.tooltip,
                          icon: destination.icon,
                          selectedIcon: destination.selectedIcon,
                          isActive: activeMenuKey == destination.menuKey,
                          onTap: () => onSelectShellRoute(destination.route),
                        ),
                    ],
                  ),
                ),
                const SidebarRailDivider(compact: true),
                Padding(
                  padding: DashboardSidebarRailMetrics.footerPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: SidebarRailUtilityGroup(
                          children: [
                            const NotificationBellButton(
                              style: NotificationBellStyle.rail,
                            ),
                            SidebarRailIcon(
                              tooltip: 'Profile',
                              icon: Icons.person_outline_rounded,
                              selectedIcon: Icons.person_rounded,
                              isActive:
                                  activeMenuKey == _SidebarMenuKey.profile,
                              onTap: () => onSelectShellRoute(
                                AppConstants.routeProfile,
                              ),
                            ),
                            SidebarRailIcon(
                              tooltip: 'More options',
                              icon: Icons.more_horiz_rounded,
                              onTap: () => _openMoreMenu(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      SidebarRailIcon(
                        tooltip: 'End session',
                        icon: Icons.logout_rounded,
                        isDestructive: true,
                        onTap: onEndSession,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarRailDestination {
  final _SidebarMenuKey menuKey;
  final String route;
  final String tooltip;
  final IconData icon;
  final IconData selectedIcon;

  const _SidebarRailDestination({
    required this.menuKey,
    required this.route,
    required this.tooltip,
    required this.icon,
    required this.selectedIcon,
  });
}

enum _RailMoreAction {
  googleClassroom,
  myCourses,
  privacySettings,
  devicePairing,
  expandSidebar,
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
  privacySettings,
  googleClassroom,
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
      return _SidebarMenuKey.profile;
    case AppConstants.routePrivacySettings:
      return _SidebarMenuKey.privacySettings;
    case AppConstants.routeGoogleClassroomSync:
      return _SidebarMenuKey.googleClassroom;
    case AppConstants.routeManualCourses:
      return _SidebarMenuKey.myCourses;
    default:
      return null;
  }
}
