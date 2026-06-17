import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrade/services/onboarding_storage_service.dart';

void main() {
  group('OnboardingStorageService', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      firestore = FakeFirebaseFirestore();
    });

    test('defaults to not seen when no data exists', () async {
      expect(
        await OnboardingStorageService.hasSeenOnboarding(
          'user_001',
          firestore: firestore,
        ),
        isFalse,
      );
    });

    test('persists hasSeenOnboarding to Firestore and local cache', () async {
      await OnboardingStorageService.setHasSeenOnboarding(
        'user_001',
        firestore: firestore,
      );

      final doc = await firestore.collection('users').doc('user_001').get();
      expect(doc.data()?['hasSeenOnboarding'], isTrue);

      expect(
        await OnboardingStorageService.hasSeenOnboarding(
          'user_001',
          firestore: firestore,
        ),
        isTrue,
      );
    });

    test('reads remote flag into local cache', () async {
      await firestore.collection('users').doc('user_002').set({
        'hasSeenOnboarding': true,
      });

      expect(
        await OnboardingStorageService.hasSeenOnboarding(
          'user_002',
          firestore: firestore,
        ),
        isTrue,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_seen_onboarding_user_002'), isTrue);
    });

    test('scopes onboarding state per uid', () async {
      await OnboardingStorageService.setHasSeenOnboarding(
        'user_a',
        firestore: firestore,
      );

      expect(
        await OnboardingStorageService.hasSeenOnboarding(
          'user_a',
          firestore: firestore,
        ),
        isTrue,
      );
      expect(
        await OnboardingStorageService.hasSeenOnboarding(
          'user_b',
          firestore: firestore,
        ),
        isFalse,
      );
    });
  });
}
