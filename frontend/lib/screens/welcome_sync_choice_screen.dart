import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/dashboard_shell_provider.dart';
import '../widgets/app_logo.dart';

/// First step after sign-in: choose to sync Google Classroom or skip to pairing / onboarding.
class WelcomeSyncChoiceScreen extends StatelessWidget {
  const WelcomeSyncChoiceScreen({super.key});

  void _goSync(BuildContext context) {
    final shell = context.read<DashboardShellProvider>();
    shell.setGoogleClassroomFromPostLoginSetup(true);
    shell.selectRoute(AppConstants.routeGoogleClassroomSync);
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppConstants.routeHome,
      (route) => false,
    );
  }

  void _goSkip(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(
      AppConstants.routeDevicePairing,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    final cardBg = isDark
        ? const Color(0xFF1E293B).withOpacity(0.96)
        : Colors.white.withOpacity(0.97);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : AppTheme.primaryBlue.withOpacity(0.12);

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2563EB),
              Color(0xFF7C3AED),
              Color(0xFF4F46E5),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: borderColor, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.45 : 0.18),
                        blurRadius: 40,
                        offset: const Offset(0, 18),
                      ),
                      BoxShadow(
                        color: AppTheme.primaryBlue.withOpacity(0.22),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: AppLogo.large()),
                        const SizedBox(height: 24),
                        Text(
                          'Welcome to',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppConstants.appName,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryBlue.withOpacity(0.12),
                                AppTheme.secondaryPurple.withOpacity(0.10),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.primaryBlue.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface
                                          .withOpacity(isDark ? 0.5 : 0.9),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: AppTheme.softShadow,
                                    ),
                                    child: Icon(
                                      Icons.cloud_sync_rounded,
                                      color: theme.colorScheme.primary,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      'Sync your courses?',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Connect Google Classroom to pull your classes and '
                                'deadlines into ${AppConstants.appName}. You can also skip '
                                'and add courses manually later.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.45,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.82),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => _goSync(context),
                          icon: const Icon(Icons.sync_rounded, size: 22),
                          label: const Text('Sync with Google Classroom'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _goSkip(context),
                          icon: const Icon(Icons.skip_next_rounded, size: 22),
                          label: const Text('Skip for now'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurface,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 18,
                            ),
                            side: BorderSide(
                              color: theme.colorScheme.outline.withOpacity(0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Next you will pair your phone (or skip) before the quick product tour.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.4,
                            color: theme.colorScheme.onSurface.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
