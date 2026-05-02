import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _dataSharingEnabled = false;
  bool get dataSharingEnabled => _dataSharingEnabled;
  bool _twoFactorEnabled = false;
  bool get twoFactorEnabled => _twoFactorEnabled;

  // AI preferences
  StudyStyle _studyStyle = StudyStyle.visual;
  StudyStyle get studyStyle => _studyStyle;

  DifficultyLevel _difficulty = DifficultyLevel.balanced;
  DifficultyLevel get difficulty => _difficulty;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final themeStr = prefs.getString('settings_theme') ?? 'light';
    _themeMode =
        themeStr == 'dark' ? ThemeMode.dark : ThemeMode.light;

    _notificationsEnabled =
        prefs.getBool('settings_notifications') ?? true;
    _aiSuggestionsEnabled =
        prefs.getBool('settings_ai_suggestions') ?? true;
    _dataSharingEnabled =
        prefs.getBool('settings_data_sharing') ?? false;
    _twoFactorEnabled =
        prefs.getBool('settings_two_factor') ?? false;

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

  Future<void> setDataSharingEnabled(bool value) async {
    _dataSharingEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_data_sharing', value);
  }

  Future<void> setTwoFactorEnabled(bool value) async {
    _twoFactorEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_two_factor', value);
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
  }
}

