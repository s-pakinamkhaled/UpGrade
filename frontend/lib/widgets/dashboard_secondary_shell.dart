import 'package:flutter/material.dart';

import '../core/dashboard_shell_navigation.dart';
import '../core/theme.dart';

/// Responsive wrapper for routes pushed on top of [MainNavigationScreen]:
/// narrow uses [narrow] as-is; wide uses a centered scroll with max width.
/// No [DashboardShellRow] — the home shell lives only in [MainNavigationScreen].
class DashboardSecondaryShell extends StatelessWidget {
  final Widget narrow;
  final Widget wideBody;
  final PreferredSizeWidget? wideAppBar;

  /// When true, [wideBody] fills the content area with no outer padding or
  /// max-width constraint (used by Notifications and similar full-page routes).
  final bool edgeToEdge;

  const DashboardSecondaryShell({
    super.key,
    required this.narrow,
    required this.wideBody,
    this.wideAppBar,
    this.edgeToEdge = false,
  });

  static const double breakpointWidth = 700;

  /// Legacy fixed cap (920). Layout now uses [contentMaxWidth]; kept for compatibility.
  @Deprecated('Use contentMaxWidth(double bodyWidth)')
  static const double maxContentWidth = 920;

  static double contentMaxWidth(double bodyWidth) {
    if (bodyWidth <= 0) return 640;
    return (bodyWidth - 40).clamp(640.0, 1320.0);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= breakpointWidth;
    if (!wide) {
      return narrow;
    }

    final theme = Theme.of(context);
    final bg = theme.colorScheme.surfaceContainerHighest;
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: edgeToEdge
          ? (isDark ? const Color(0xFF111827) : AppTheme.white)
          : (isDark ? theme.scaffoldBackgroundColor : bg),
      appBar: wideAppBar ??
          AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => returnToMainShellFromOverlay(context),
              tooltip: 'Back',
            ),
          ),
      body: SafeArea(
        child: edgeToEdge
            ? wideBody
            : LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = contentMaxWidth(constraints.maxWidth);
                  final hPad = constraints.maxWidth > 1100 ? 28.0 : 20.0;
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: hPad,
                      vertical: 16,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxW),
                        child: wideBody,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
