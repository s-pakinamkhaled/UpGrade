import 'package:flutter/material.dart';

/// Responsive wrapper for routes pushed on top of [MainNavigationScreen]:
/// narrow uses [narrow] as-is; wide uses a centered scroll with max width.
/// No [DashboardShellRow] — the home shell lives only in [MainNavigationScreen].
class DashboardSecondaryShell extends StatelessWidget {
  final Widget narrow;
  final Widget wideBody;
  final PreferredSizeWidget? wideAppBar;

  const DashboardSecondaryShell({
    super.key,
    required this.narrow,
    required this.wideBody,
    this.wideAppBar,
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
    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? theme.scaffoldBackgroundColor
          : bg,
      appBar: wideAppBar ??
          AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.maybePop(context),
              tooltip: 'Back',
            ),
          ),
      body: SafeArea(
        child: LayoutBuilder(
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
