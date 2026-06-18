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
      expect(settings.studyStyle, StudyStyle.visual);
      expect(settings.difficulty, DifficultyLevel.balanced);
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.aiSuggestionsEnabled, isTrue);
    });

    test('persists study style preference', () async {
      await settings.load();

      await settings.setStudyStyle(StudyStyle.practice);
      expect(settings.studyStyle, StudyStyle.practice);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings_study_style'), 'practice');
    });

    test('persists planner difficulty preference', () async {
      await settings.load();

      await settings.setDifficulty(DifficultyLevel.challenging);
      expect(settings.difficulty, DifficultyLevel.challenging);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings_difficulty'), 'challenging');
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

    test('restores saved preferences on reload', () async {
      SharedPreferences.setMockInitialValues({
        'settings_study_style': 'reading',
        'settings_difficulty': 'easy',
        'settings_notifications': false,
        'settings_ai_suggestions': false,
      });

      final reloaded = SettingsProvider();
      await reloaded.load();

      expect(reloaded.studyStyle, StudyStyle.reading);
      expect(reloaded.difficulty, DifficultyLevel.easy);
      expect(reloaded.notificationsEnabled, isFalse);
      expect(reloaded.aiSuggestionsEnabled, isFalse);
    });

    test('notifies listeners when preferences change', () async {
      await settings.load();
      var notifications = 0;
      settings.addListener(() => notifications++);

      await settings.setStudyStyle(StudyStyle.reading);
      await settings.setDifficulty(DifficultyLevel.easy);

      expect(notifications, greaterThanOrEqualTo(2));
    });
  });
}
