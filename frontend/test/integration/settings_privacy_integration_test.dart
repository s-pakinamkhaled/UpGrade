import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/providers/settings_provider.dart';

import 'helpers/integration_app_harness.dart';

void main() {
  group('Privacy settings flow (integration)', () {
    testWidgets('toggle dark mode and study style updates provider state',
        (tester) async {
      resetIntegrationPrefs();
      final settings = SettingsProvider();
      await settings.load();

      await tester.pumpWidget(buildPrivacyIntegrationApp(settingsProvider: settings));
      await tester.pumpAndSettle();

      expect(settings.themeMode, ThemeMode.light);
      expect(settings.studyStyle, StudyStyle.visual);

      await tester.tap(find.text('Dark Mode'));
      await tester.pumpAndSettle();

      final darkSwitch = find.descendant(
        of: find.ancestor(
          of: find.text('Dark Mode'),
          matching: find.byType(Row),
        ),
        matching: find.byType(Switch),
      );
      await tester.tap(darkSwitch);
      await tester.pumpAndSettle();

      expect(settings.themeMode, ThemeMode.dark);

      await tester.tap(find.text('Practice'));
      await tester.pumpAndSettle();

      expect(settings.studyStyle, StudyStyle.practice);
    });

    testWidgets('planner difficulty persists across widget rebuild', (tester) async {
      resetIntegrationPrefs();
      final settings = SettingsProvider();
      await settings.load();

      await tester.pumpWidget(buildPrivacyIntegrationApp(settingsProvider: settings));
      await tester.pumpAndSettle();

      await settings.setDifficulty(DifficultyLevel.challenging);
      await tester.pumpAndSettle();

      expect(settings.difficulty, DifficultyLevel.challenging);

      await tester.pumpWidget(buildPrivacyIntegrationApp(settingsProvider: settings));
      await tester.pumpAndSettle();

      expect(find.text('Challenging'), findsWidgets);
    });
  });
}
