import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether a user has completed product onboarding (per Firebase uid).
class OnboardingStorageService {
  static const String _localKey = 'has_seen_onboarding';
  static const String _firestoreField = 'hasSeenOnboarding';

  static String _scopedLocalKey(String uid) => '${_localKey}_$uid';

  static Future<bool> hasSeenOnboarding(
    String uid, {
    FirebaseFirestore? firestore,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getBool(_scopedLocalKey(uid));
    if (local == true) return true;

    try {
      final doc = await (firestore ?? FirebaseFirestore.instance)
          .collection('users')
          .doc(uid)
          .get();
      final remote = doc.data()?[_firestoreField] as bool? ?? false;
      if (remote) {
        await prefs.setBool(_scopedLocalKey(uid), true);
      }
      return remote;
    } catch (_) {
      return local ?? false;
    }
  }

  static Future<void> setHasSeenOnboarding(
    String uid, {
    FirebaseFirestore? firestore,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedLocalKey(uid), true);

    await (firestore ?? FirebaseFirestore.instance)
        .collection('users')
        .doc(uid)
        .set({
      _firestoreField: true,
      'onboardingCompletedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
