import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/core/profile_display_name.dart';

void main() {
  group('displayNameFromEmail', () {
    test('formats simple email local part', () {
      expect(displayNameFromEmail('pakinam@example.com'), 'Pakinam');
    });

    test('formats dotted and underscored names', () {
      expect(displayNameFromEmail('pakinam.ali@x.com'), 'Pakinam Ali');
      expect(displayNameFromEmail('pakinam_ali@x.com'), 'Pakinam Ali');
    });

    test('returns User for empty or invalid email', () {
      expect(displayNameFromEmail(null), 'User');
      expect(displayNameFromEmail(''), 'User');
      expect(displayNameFromEmail('   '), 'User');
    });
  });

  group('profile placeholders', () {
    test('detects placeholder profile names', () {
      expect(isPlaceholderProfileName(null), isTrue);
      expect(isPlaceholderProfileName(''), isTrue);
      expect(isPlaceholderProfileName('John Doe'), isTrue);
      expect(isPlaceholderProfileName('Pakinam Ahmed'), isFalse);
    });

    test('detects placeholder profile emails', () {
      expect(isPlaceholderProfileEmail(null), isTrue);
      expect(isPlaceholderProfileEmail('john.doe@university.edu'), isTrue);
      expect(isPlaceholderProfileEmail('pakinam@test.com'), isFalse);
    });

    test('does not treat script-like display names as placeholders', () {
      expect(isPlaceholderProfileName('<script>alert(1)</script>'), isFalse);
    });
  });
}
