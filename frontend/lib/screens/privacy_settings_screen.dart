import 'package:flutter/material.dart';

import '../widgets/upgrade_page_shell.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UpGradePageShell(
      title: 'Privacy Settings',
      subtitle: 'Control how your data is used in UpGrade',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coming soon',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You will be able to manage data retention, analytics, and AI training preferences here.',
          ),
        ],
      ),
    );
  }
}

