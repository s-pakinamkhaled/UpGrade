import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Shared sizing tokens for the collapsed navigation rail.
class DashboardSidebarRailMetrics {
  DashboardSidebarRailMetrics._();

  /// Collapsed navigation rail width (stable across shell animation).
  static const double width = 72;
  static const double itemSize = 44;
  static const double iconSize = 25;
  static const double itemSpacing = 2;
  static const double horizontalInset = (width - itemSize) / 2;
  static const EdgeInsets headerPadding =
      EdgeInsets.only(top: 6, bottom: 4);
  static const EdgeInsets navPadding =
      EdgeInsets.symmetric(vertical: 4);
  static const EdgeInsets footerPadding =
      EdgeInsets.only(top: 4, bottom: 8);
  static const Duration motionDuration = Duration(milliseconds: 200);
  static const Curve motionCurve = Curves.easeOutCubic;

  static Color navInactiveFor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
  }

  static Color hoverFillFor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.06)
        : const Color(0xFF0F172A).withOpacity(0.05);
  }

  static Color activeFillFor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppTheme.primaryBlue.withOpacity(0.22)
        : AppTheme.primaryBlue.withOpacity(0.12);
  }

  static Color utilityGroupFillFor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.04)
        : const Color(0xFF0F172A).withOpacity(0.035);
  }
}

/// Material 3 navigation-rail icon with hover, active pill, and accent bar.
class SidebarRailIcon extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final IconData? selectedIcon;
  final bool isActive;
  final VoidCallback onTap;
  final int? badgeCount;
  final Color? iconColor;
  final bool isDestructive;

  const SidebarRailIcon({
    super.key,
    required this.tooltip,
    required this.icon,
    this.selectedIcon,
    this.isActive = false,
    required this.onTap,
    this.badgeCount,
    this.iconColor,
    this.isDestructive = false,
  });

  @override
  State<SidebarRailIcon> createState() => _SidebarRailIconState();
}

class _SidebarRailIconState extends State<SidebarRailIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor =
        widget.iconColor ?? DashboardSidebarRailMetrics.navInactiveFor(context);
    final showBadge = (widget.badgeCount ?? 0) > 0;

    Color iconColor;
    Color? fillColor;
    if (widget.isDestructive) {
      iconColor = AppTheme.errorRed;
      fillColor = widget.isActive || _hovered
          ? AppTheme.errorRed.withOpacity(isDark ? 0.18 : 0.1)
          : null;
    } else if (widget.isActive) {
      iconColor = AppTheme.primaryBlue;
      fillColor = DashboardSidebarRailMetrics.activeFillFor(context);
    } else if (_hovered) {
      iconColor = isDark ? Colors.white : AppTheme.darkText;
      fillColor = DashboardSidebarRailMetrics.hoverFillFor(context);
    } else {
      iconColor = inactiveColor;
      fillColor = null;
    }

    Widget iconWidget = Icon(
      widget.isActive ? (widget.selectedIcon ?? widget.icon) : widget.icon,
      size: DashboardSidebarRailMetrics.iconSize,
      color: iconColor,
    );

    if (showBadge) {
      iconWidget = Badge(
        isLabelVisible: true,
        backgroundColor: AppTheme.errorRed,
        alignment: Alignment.topRight,
        offset: const Offset(2, -2),
        label: Text(
          widget.badgeCount! > 99 ? '99+' : '${widget.badgeCount}',
          style: const TextStyle(
            color: AppTheme.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        child: iconWidget,
      );
    }

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: DashboardSidebarRailMetrics.itemSpacing,
        ),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(14),
              splashColor: AppTheme.primaryBlue.withOpacity(0.08),
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              child: SizedBox(
                width: double.infinity,
                height: DashboardSidebarRailMetrics.itemSize,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: DashboardSidebarRailMetrics.motionDuration,
                      curve: DashboardSidebarRailMetrics.motionCurve,
                      width: DashboardSidebarRailMetrics.itemSize,
                      height: DashboardSidebarRailMetrics.itemSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: fillColor,
                        boxShadow: widget.isActive && !widget.isDestructive
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryBlue
                                      .withOpacity(isDark ? 0.18 : 0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(child: iconWidget),
                    ),
                    Positioned(
                      left: 0,
                      top: widget.isActive ? 10 : 22,
                      bottom: widget.isActive ? 10 : 22,
                      child: AnimatedContainer(
                        duration: DashboardSidebarRailMetrics.motionDuration,
                        curve: DashboardSidebarRailMetrics.motionCurve,
                        width: 3,
                        decoration: BoxDecoration(
                          color: widget.isActive && !widget.isDestructive
                              ? AppTheme.primaryBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SidebarRailDivider extends StatelessWidget {
  final bool compact;

  const SidebarRailDivider({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: DashboardSidebarRailMetrics.horizontalInset + 2,
        vertical: compact ? 4 : 6,
      ),
      child: Divider(
        height: 1,
        thickness: 1,
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
      ),
    );
  }
}

/// Groups utility actions (notifications, profile, more) with subtle elevation.
class SidebarRailUtilityGroup extends StatelessWidget {
  final List<Widget> children;

  const SidebarRailUtilityGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: DashboardSidebarRailMetrics.itemSize,
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: DashboardSidebarRailMetrics.utilityGroupFillFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.05)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
