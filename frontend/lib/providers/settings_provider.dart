import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_matching_profile_sync_service.dart';

enum StudyStyle { visual, reading, practice }
enum DifficultyLevel { easy, balanced, challenging }

class SettingsProvider extends ChangeNotifier {
  // Theme
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  // Toggles
  bool _notificationsEnabled = true;
  bool get notificationsEnabled => _notificationsEnabled;

  bool _aiSuggestionsEnabled = true;
  bool get aiSuggestionsEnabled => _aiSuggestionsEnabled;

  // AI preferences
  StudyStyle _studyStyle = StudyStyle.visual;
  StudyStyle get studyStyle => _studyStyle;

  DifficultyLevel _difficulty = DifficultyLevel.balanced;
  DifficultyLevel get difficulty => _difficulty;

  bool _loaded = false;
  bool get isLoaded => _loaded;
  String _availableStart = '18:00';
  String get availableStart => _availableStart;
  String _availableEnd = '21:00';
  String get availableEnd => _availableEnd;

  String? _preferredStudyTime;
  String? get preferredStudyTime => _preferredStudyTime;

  String? _dailyStudyGoal;
  String? get dailyStudyGoal => _dailyStudyGoal;

  String? _reminderTime;
  String? get reminderTime => _reminderTime;

  String? _focusSessionDuration;
  String? get focusSessionDuration => _focusSessionDuration;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final themeStr = prefs.getString('settings_theme') ?? 'light';
    _themeMode =
        themeStr == 'dark' ? ThemeMode.dark : ThemeMode.light;

    _notificationsEnabled =
        prefs.getBool('settings_notifications') ?? true;
    _aiSuggestionsEnabled =
        prefs.getBool('settings_ai_suggestions') ?? true;

    final styleStr = prefs.getString('settings_study_style') ?? 'visual';
    switch (styleStr) {
      case 'reading':
        _studyStyle = StudyStyle.reading;
        break;
      case 'practice':
        _studyStyle = StudyStyle.practice;
        break;
      default:
        _studyStyle = StudyStyle.visual;
    }

    final diffStr = prefs.getString('settings_difficulty') ?? 'balanced';
    switch (diffStr) {
      case 'easy':
        _difficulty = DifficultyLevel.easy;
        break;
      case 'challenging':
        _difficulty = DifficultyLevel.challenging;
        break;
      default:
        _difficulty = DifficultyLevel.balanced;
    }

    _availableStart = prefs.getString('profile_available_start') ?? '18:00';
    _availableEnd = prefs.getString('profile_available_end') ?? '21:00';

    _preferredStudyTime = prefs.getString('profile_preferred_study_time');
    _dailyStudyGoal = prefs.getString('profile_daily_study_goal');
    _reminderTime = prefs.getString('profile_reminder_time');
    _focusSessionDuration = prefs.getString('profile_focus_session_duration');

    _loaded = true;
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings_theme', isDark ? 'dark' : 'light');
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_notifications', value);
  }

  Future<void> setAiSuggestionsEnabled(bool value) async {
    _aiSuggestionsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_ai_suggestions', value);
  }

  Future<void> setStudyStyle(StudyStyle style) async {
    _studyStyle = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final value = switch (style) {
      StudyStyle.visual => 'visual',
      StudyStyle.reading => 'reading',
      StudyStyle.practice => 'practice',
    };
    await prefs.setString('settings_study_style', value);
    try {
      await UserMatchingProfileSyncService.syncCurrentUserProfile();
    } catch (_) {
      // Profile sync is best-effort when Firebase is unavailable (e.g. tests).
    }
  }

  Future<void> setDifficulty(DifficultyLevel level) async {
    _difficulty = level;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final value = switch (level) {
      DifficultyLevel.easy => 'easy',
      DifficultyLevel.balanced => 'balanced',
      DifficultyLevel.challenging => 'challenging',
    };
    await prefs.setString('settings_difficulty', value);
    try {
      await UserMatchingProfileSyncService.syncCurrentUserProfile();
    } catch (_) {
      // Profile sync is best-effort when Firebase is unavailable (e.g. tests).
    }
  }

  Future<void> setAvailability({
    required String startHHmm,
    required String endHHmm,
  }) async {
    _availableStart = startHHmm;
    _availableEnd = endHHmm;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_available_start', startHHmm);
    await prefs.setString('profile_available_end', endHHmm);
    await UserMatchingProfileSyncService.syncCurrentUserProfile();
  }

  Future<void> setStudyPreferences({
    String? preferredStudyTime,
    String? dailyStudyGoal,
    String? reminderTime,
    String? focusSessionDuration,
  }) async {
    _preferredStudyTime = _trimOrNull(preferredStudyTime);
    _dailyStudyGoal = _trimOrNull(dailyStudyGoal);
    _reminderTime = _trimOrNull(reminderTime);
    _focusSessionDuration = _trimOrNull(focusSessionDuration);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await _setNullableString(
      prefs,
      'profile_preferred_study_time',
      _preferredStudyTime,
    );
    await _setNullableString(prefs, 'profile_daily_study_goal', _dailyStudyGoal);
    await _setNullableString(prefs, 'profile_reminder_time', _reminderTime);
    await _setNullableString(
      prefs,
      'profile_focus_session_duration',
      _focusSessionDuration,
    );
  }

  static String? _trimOrNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static Future<void> _setNullableString(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }

  static String labelForStudyStyle(StudyStyle style) => switch (style) {
        StudyStyle.visual => 'Visual',
        StudyStyle.reading => 'Reading',
        StudyStyle.practice => 'Practice',
      };

  static String labelForDifficulty(DifficultyLevel level) => switch (level) {
        DifficultyLevel.easy => 'Easy',
        DifficultyLevel.balanced => 'Balanced',
        DifficultyLevel.challenging => 'Challenging',
      };
}

