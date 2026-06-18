import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/core/constants.dart';

void main() {
  group('Device pairing route selection', () {
    test('wide web hosts the QR code', () {
      expect(
        AppConstants.shouldUsePairingScanner(
          isWeb: true,
          platform: TargetPlatform.windows,
          viewportWidth: 1280,
        ),
        isFalse,
      );
    });

    test('narrow mobile web opens the camera scanner', () {
      expect(
        AppConstants.shouldUsePairingScanner(
          isWeb: true,
          platform: TargetPlatform.android,
          viewportWidth: 390,
        ),
        isTrue,
      );
    });

    test('native Android and iOS always scan', () {
      expect(
        AppConstants.shouldUsePairingScanner(
          isWeb: false,
          platform: TargetPlatform.android,
          viewportWidth: 1280,
        ),
        isTrue,
      );
      expect(
        AppConstants.shouldUsePairingScanner(
          isWeb: false,
          platform: TargetPlatform.iOS,
          viewportWidth: 1280,
        ),
        isTrue,
      );
    });

    test('desktop native apps host the QR code', () {
      expect(
        AppConstants.shouldUsePairingScanner(
          isWeb: false,
          platform: TargetPlatform.windows,
          viewportWidth: 1280,
        ),
        isFalse,
      );
      expect(
        AppConstants.shouldUsePairingScanner(
          isWeb: false,
          platform: TargetPlatform.macOS,
          viewportWidth: 800,
        ),
        isFalse,
      );
    });
  });
}
