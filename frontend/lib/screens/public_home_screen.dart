import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';

import '../core/constants.dart';
import '../core/theme.dart';

class PublicHomeScreen extends StatelessWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
=======
    final theme = Theme.of(context);
    final headlineColor = theme.colorScheme.onSurface;
    final bodyColor = theme.colorScheme.onSurface.withOpacity(0.85);
    final secondaryColor = theme.colorScheme.onSurface.withOpacity(0.75);
>>>>>>> main
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppConstants.appName,
<<<<<<< HEAD
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
=======
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: headlineColor,
                  ),
>>>>>>> main
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '${AppConstants.appTagline}. Plan study time, sync with Classroom, and stay on track with AI-powered guidance.',
<<<<<<< HEAD
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.darkText.withOpacity(0.85),
                        height: 1.4,
                      ),
=======
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: bodyColor,
                    height: 1.4,
                  ),
>>>>>>> main
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'No sign-in is required to read about the app or review our Privacy Policy.',
<<<<<<< HEAD
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.darkText.withOpacity(0.75),
                        height: 1.35,
                      ),
=======
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: secondaryColor,
                    height: 1.35,
                  ),
>>>>>>> main
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SelectableText(
                  AppConstants.publicPrivacyPolicyPageUrl,
<<<<<<< HEAD
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.primaryBlue,
                      ),
=======
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.primaryBlue,
                  ),
>>>>>>> main
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
<<<<<<< HEAD
                      Navigator.pushNamed(context, '/login');
=======
                      Navigator.pushNamed(context, AppConstants.routeLogin);
>>>>>>> main
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Open App'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: kIsWeb
                      ? Link(
<<<<<<< HEAD
                          uri:
                              Uri.parse(AppConstants.publicPrivacyPolicyPageUrl),
                          builder: (context, followLink) => OutlinedButton(
                            onPressed: followLink,
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
=======
                          uri: Uri.parse(
                              AppConstants.publicPrivacyPolicyPageUrl),
                          builder: (context, followLink) => OutlinedButton(
                            onPressed: followLink,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
>>>>>>> main
                            ),
                            child: const Text('Privacy Policy'),
                          ),
                        )
                      : OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppConstants.routePrivacy,
                            );
                          },
                          style: OutlinedButton.styleFrom(
<<<<<<< HEAD
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
=======
                            padding: const EdgeInsets.symmetric(vertical: 16),
>>>>>>> main
                          ),
                          child: const Text('Privacy Policy'),
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
