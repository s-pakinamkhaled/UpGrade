import 'package:flutter/material.dart';

import '../widgets/upgrade_page_shell.dart';

/// Mirrors content in [public/privacy.html] for native platforms.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return UpGradePageShell(
      title: 'Privacy Policy',
      subtitle: 'AI-Powered Study Assistant',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Information We Collect',
              style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'UpGrade uses Google Sign-In to authenticate users. When you sign in, we access:',
            ),
            const SizedBox(height: 8),
            _bullet(theme, 'Basic profile information (name and email address)'),
            _bullet(theme, 'Profile picture (optional, for display purposes only)'),
            const SizedBox(height: 16),
            Text(
              'Google Classroom Integration',
              style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'If you choose to connect Google Classroom, we access:',
            ),
            const SizedBox(height: 8),
            _bullet(theme, 'Your enrolled courses (read-only)'),
            _bullet(theme, 'Course assignments and deadlines (read-only)'),
            _bullet(theme, 'Your submission status and grades (read-only)'),
            const SizedBox(height: 8),
            const Text(
              'This data is used solely to display your assignments and help you plan your studies effectively.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'We do not store, sell, or share your personal data with third parties. All data is processed locally on your device.',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Data Security',
              style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'We take your privacy seriously. Your Google account credentials are never stored by UpGrade. Authentication is handled securely through Google\'s OAuth 2.0 system.',
            ),
            const SizedBox(height: 16),
            Text(
              'Your Rights',
              style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('You have full control over your data:'),
            const SizedBox(height: 8),
            _bullet(
              theme,
              'You can revoke UpGrade\'s access at any time from your Google Account settings (myaccount.google.com/permissions).',
            ),
            _bullet(
              theme,
              'You can request deletion of any stored data by contacting us',
            ),
            _bullet(
              theme,
              'You can use the app without connecting Google Classroom',
            ),
            const SizedBox(height: 16),
            Text(
              'Changes to This Policy',
              style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'We may update this privacy policy from time to time. Any changes will be posted on this page with an updated revision date.',
            ),
            const SizedBox(height: 16),
            Text(
              'Contact Us',
              style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'If you have any questions about this Privacy Policy, please contact us at:',
            ),
            const SizedBox(height: 4),
            SelectableText(
              'pakinamkhaled10@gmail.com',
              style: theme.bodyMedium?.copyWith(
                decoration: TextDecoration.underline,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Last updated: February 20, 2026',
              style: theme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _bullet(TextTheme theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: theme.bodyMedium),
          Expanded(child: Text(text, style: theme.bodyMedium)),
        ],
      ),
    );
  }
}
