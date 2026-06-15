import 'package:shared_preferences/shared_preferences.dart';

/// Persists device pairing status per Firebase uid (set when pairing succeeds).
class DevicePairingStorageService {
  static const String _keyPaired = 'device_paired';
  static const String _keyDeviceName = 'device_paired_name';

  static String _scoped(String base, String uid) => '${base}_$uid';

  static Future<void> setPaired({
    required String uid,
    required bool paired,
    String? deviceName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scoped(_keyPaired, uid), paired);
    if (paired && deviceName != null && deviceName.trim().isNotEmpty) {
      await prefs.setString(_scoped(_keyDeviceName, uid), deviceName.trim());
    } else if (!paired) {
      await prefs.remove(_scoped(_keyDeviceName, uid));
    }
  }

  static Future<bool> isPaired(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scoped(_keyPaired, uid)) ?? false;
  }

  static Future<String?> deviceName(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scoped(_keyDeviceName, uid));
  }

  static Future<void> clearForUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scoped(_keyPaired, uid));
    await prefs.remove(_scoped(_keyDeviceName, uid));
  }
}
