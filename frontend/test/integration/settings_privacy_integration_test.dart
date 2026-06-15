import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/providers/settings_provider.dart';

import 'helpers/integration_app_harness.dart';

void main() {
  group('Privacy settings flow (integration)', () {
    testWidgets('toggle dark mode and data sharing updates provider state',
        (tester) async {
      resetIntegrationPrefs();
      final settings = SettingsProvider();
      await settings.load();

      await tester.pumpWidget(buildPrivacyIntegrationApp(settingsProvider: settings));
      await tester.pumpAndSettle();

      expect(settings.themeMode, ThemeMode.light);
      expect(settings.dataSharingEnabled, isFalse);

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

      await tester.tap(find.text('Data Sharing'));
      await tester.pumpAndSettle();

      final shareSwitch = find.descendant(
        of: find.ancestor(
          of: find.text('Data Sharing'),
          matching: find.byType(Row),
        ),
        matching: find.byType(Switch),
      );
      await tester.tap(shareSwitch);
      await tester.pumpAndSettle();

      expect(settings.dataSharingEnabled, isTrue);
    });

    testWidgets('privacy toggles persist across widget rebuild', (tester) async {
      resetIntegrationPrefs();
      final settings = SettingsProvider();
      await settings.load();

      await tester.pumpWidget(buildPrivacyIntegrationApp(settingsProvider: settings));
      await tester.pumpAndSettle();

      await settings.setTwoFactorEnabled(true);
      await tester.pumpAndSettle();

      expect(settings.twoFactorEnabled, isTrue);

      await tester.pumpWidget(buildPrivacyIntegrationApp(settingsProvider: settings));
      await tester.pumpAndSettle();

      final twoFactorSwitch = find.descendant(
        of: find.ancestor(
          of: find.text('Two-Factor Authentication'),
          matching: find.byType(Row),
        ),
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(twoFactorSwitch).value, isTrue);
    });
  });
}
