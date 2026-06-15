import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/dashboard_shell_navigation.dart';
import '../providers/dashboard_shell_provider.dart';
import 'dashboard_sidebar.dart';
import 'upgrade_visual_system.dart';

/// Sidebar animation tuned for snappy Material 3 motion (<150ms perceived).
const Duration kSidebarMotionDuration = Duration(milliseconds: 150);
const Curve kSidebarMotionCurve = Curves.easeOutCubic;

/// Minimum viewport width for expand/collapse (tablet shell uses rail below this).
const double kSidebarExpandBreakpoint = 600;

/// Lightweight snapshot for [Selector] — rebuild sidebar only when these change.
@immutable
class _SidebarShellState {
  final bool expanded;
  final String selectedRoute;

  const _SidebarShellState({
    required this.expanded,
    required this.selectedRoute,
  });

  @override
  bool operator ==(Object other) {
    return other is _SidebarShellState &&
        other.expanded == expanded &&
        other.selectedRoute == selectedRoute;
  }

  @override
  int get hashCode => Object.hash(expanded, selectedRoute);
}

/// Sidebar + main body for [MainNavigationScreen] only.
/// Main tabs switch via [DashboardShellProvider.selectRoute]; auxiliary items use [Navigator.pushNamed].
class DashboardShellRow extends StatelessWidget {
  final Widget body;

  const DashboardShellRow({super.key, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Selector<DashboardShellProvider, _SidebarShellState>(
          selector: (_, shell) => _SidebarShellState(
            expanded: shell.sidebarExpanded,
            selectedRoute: shell.selectedRoute,
          ),
          builder: (context, sidebarState, _) {
            final layoutW = MediaQuery.sizeOf(context).width;
            final canExpandSidebar = layoutW >= kSidebarExpandBreakpoint;
            final targetExpanded =
                canExpandSidebar && sidebarState.expanded;

            void navigateFromSidebar(String route) {
              if (route == AppConstants.routeEndSession) {
                context.read<DashboardShellProvider>().enterEndSession();
                return;
              }
              context.read<DashboardShellProvider>().selectRoute(route);
            }

            void pushAuxiliaryFromSidebar(String route) {
              Navigator.of(context).pushNamed(route);
            }

            void enterEndSession() {
              enterMainShellEndSession(context);
            }

            return RepaintBoundary(
              child: _AnimatedSidebarSlot(
                targetExpanded: targetExpanded,
                canExpandSidebar: canExpandSidebar,
                selectedRoute: sidebarState.selectedRoute,
                onSelectShellRoute: navigateFromSidebar,
                onPushAuxiliaryRoute: pushAuxiliaryFromSidebar,
                onEndSession: enterEndSession,
                onCollapse: () => context
                    .read<DashboardShellProvider>()
                    .setSidebarExpanded(false),
                onExpand: () {
                  if (canExpandSidebar) {
                    context
                        .read<DashboardShellProvider>()
                        .setSidebarExpanded(true);
                  }
                },
              ),
            );
          },
        ),
        Expanded(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: UpGradePageDecor.pageBackground(
                Theme.of(context).brightness == Brightness.dark,
              ),
              child: body,
            ),
          ),
        ),
      ],
    );
  }
}

/// Animates shell width without laying out the expanded sidebar below its width.
///
/// Expand: grow rail width first, then swap to the full sidebar when done.
/// Collapse: swap to rail immediately, then shrink width — avoids RenderFlex overflow.
class _AnimatedSidebarSlot extends StatefulWidget {
  final bool targetExpanded;
  final bool canExpandSidebar;
  final String selectedRoute;
  final void Function(String route) onSelectShellRoute;
  final void Function(String route) onPushAuxiliaryRoute;
  final VoidCallback onEndSession;
  final VoidCallback onCollapse;
  final VoidCallback onExpand;

  const _AnimatedSidebarSlot({
    required this.targetExpanded,
    required this.canExpandSidebar,
    required this.selectedRoute,
    required this.onSelectShellRoute,
    required this.onPushAuxiliaryRoute,
    required this.onEndSession,
    required this.onCollapse,
    required this.onExpand,
  });

  @override
  State<_AnimatedSidebarSlot> createState() => _AnimatedSidebarSlotState();
}

class _AnimatedSidebarSlotState extends State<_AnimatedSidebarSlot>
    with SingleTickerProviderStateMixin {
  late AnimationController _widthController;
  late Animation<double> _widthAnimation;

  /// Which sidebar variant is currently built (may lag [widget.targetExpanded] during expand).
  late bool _showExpandedChrome;

  @override
  void initState() {
    super.initState();
    _showExpandedChrome = widget.targetExpanded;
    _widthController = AnimationController(
      vsync: this,
      duration: kSidebarMotionDuration,
      value: widget.targetExpanded ? 1.0 : 0.0,
    );
    _widthAnimation = CurvedAnimation(
      parent: _widthController,
      curve: kSidebarMotionCurve,
    );
    _widthController.addListener(_onWidthTick);
  }

  void _onWidthTick() {
    final displayExpanded = _displayExpandedChrome;
    if (displayExpanded != _showExpandedChrome) {
      setState(() => _showExpandedChrome = displayExpanded);
    }
  }

  @override
  void didUpdateWidget(_AnimatedSidebarSlot oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.targetExpanded == widget.targetExpanded) return;

    if (widget.targetExpanded) {
      _widthController.forward();
    } else {
      setState(() => _showExpandedChrome = false);
      _widthController.reverse();
    }
  }

  bool get _displayExpandedChrome {
    if (!widget.targetExpanded) return false;
    // Swap once the slot is wide enough for the expanded header (~230px).
    return _widthAnimation.value >= 0.85;
  }

  @override
  void dispose() {
    _widthController.removeListener(_onWidthTick);
    _widthController.dispose();
    super.dispose();
  }

  Widget _buildSidebarContent() {
    if (_showExpandedChrome) {
      return DashboardSidebar(
        key: const ValueKey('sidebar-expanded'),
        selectedRoute: widget.selectedRoute,
        onSelectShellRoute: widget.onSelectShellRoute,
        onPushAuxiliaryRoute: widget.onPushAuxiliaryRoute,
        onEndSession: widget.onEndSession,
        onCollapse: widget.onCollapse,
      );
    }
    return DashboardSidebarCollapsedRail(
      key: const ValueKey('sidebar-collapsed'),
      selectedRoute: widget.selectedRoute,
      onExpand: widget.onExpand,
      onSelectShellRoute: widget.onSelectShellRoute,
      onPushAuxiliaryRoute: widget.onPushAuxiliaryRoute,
      onEndSession: widget.onEndSession,
    );
  }

  @override
  Widget build(BuildContext context) {
    final collapsedW = DashboardSidebarCollapsedRail.railWidth;
    final expandedW = DashboardSidebar.width;

    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, _) {
        final slotWidth = collapsedW +
            (expandedW - collapsedW) * _widthAnimation.value;
        final contentWidth = _showExpandedChrome
            ? slotWidth.clamp(collapsedW, expandedW)
            : collapsedW;

        return ClipRect(
          child: SizedBox(
            width: slotWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: contentWidth,
                child: RepaintBoundary(child: _buildSidebarContent()),
              ),
            ),
          ),
        );
      },
    );
  }
}
