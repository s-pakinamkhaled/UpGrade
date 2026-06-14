import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrade/providers/settings_provider.dart';

void main() {
  group('SettingsProvider privacy toggles (SharedPreferences mock)', () {
    late SettingsProvider settings;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsProvider();
    });

    test('loads default privacy-friendly settings', () async {
      await settings.load();

      expect(settings.isLoaded, isTrue);
      expect(settings.dataSharingEnabled, isFalse);
      expect(settings.twoFactorEnabled, isFalse);
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.aiSuggestionsEnabled, isTrue);
    });

    test('persists data sharing opt-in/out', () async {
      await settings.load();

      await settings.setDataSharingEnabled(true);
      expect(settings.dataSharingEnabled, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings_data_sharing'), isTrue);

      await settings.setDataSharingEnabled(false);
      expect(settings.dataSharingEnabled, isFalse);
      expect(prefs.getBool('settings_data_sharing'), isFalse);
    });

    test('persists two-factor toggle', () async {
      await settings.load();

      await settings.setTwoFactorEnabled(true);
      expect(settings.twoFactorEnabled, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings_two_factor'), isTrue);
    });

    test('persists notification and AI suggestion toggles', () async {
      await settings.load();

      await settings.setNotificationsEnabled(false);
      await settings.setAiSuggestionsEnabled(false);

      expect(settings.notificationsEnabled, isFalse);
      expect(settings.aiSuggestionsEnabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings_notifications'), isFalse);
      expect(prefs.getBool('settings_ai_suggestions'), isFalse);
    });

    test('restores saved privacy preferences on reload', () async {
      SharedPreferences.setMockInitialValues({
        'settings_data_sharing': true,
        'settings_two_factor': true,
        'settings_notifications': false,
        'settings_ai_suggestions': false,
      });

      final reloaded = SettingsProvider();
      await reloaded.load();

      expect(reloaded.dataSharingEnabled, isTrue);
      expect(reloaded.twoFactorEnabled, isTrue);
      expect(reloaded.notificationsEnabled, isFalse);
      expect(reloaded.aiSuggestionsEnabled, isFalse);
    });

    test('notifies listeners when privacy toggles change', () async {
      await settings.load();
      var notifications = 0;
      settings.addListener(() => notifications++);

      await settings.setDataSharingEnabled(true);
      await settings.setTwoFactorEnabled(true);

      expect(notifications, greaterThanOrEqualTo(2));
    });
  });
}
