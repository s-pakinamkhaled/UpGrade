import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/core/security_utils.dart';

void main() {
  group('SecurityUtils email validation', () {
    test('accepts normal emails', () {
      expect(SecurityUtils.isValidEmail('pakinam@test.com'), isTrue);
      expect(SecurityUtils.isValidEmail('  user.name@university.edu  '), isTrue);
    });

    test('rejects malformed emails', () {
      expect(SecurityUtils.isValidEmail(null), isFalse);
      expect(SecurityUtils.isValidEmail(''), isFalse);
      expect(SecurityUtils.isValidEmail('not-an-email'), isFalse);
      expect(SecurityUtils.isValidEmail('missing-at.com'), isFalse);
      expect(SecurityUtils.isValidEmail('bad@domain'), isFalse);
      expect(SecurityUtils.isValidEmail('spaces @test.com'), isFalse);
      expect(SecurityUtils.isValidEmail('a@b.c'), isFalse);
    });

    test('login/register validators align with rules', () {
      expect(SecurityUtils.validateLoginEmail(''), isNotNull);
      expect(SecurityUtils.validateLoginEmail('bad'), isNotNull);
      expect(SecurityUtils.validateLoginEmail('ok@test.com'), isNull);

      expect(SecurityUtils.validatePassword('123'), isNotNull);
      expect(SecurityUtils.validatePassword('123456'), isNull);

      expect(
        SecurityUtils.validatePasswordConfirmation('abc123', 'abc124'),
        isNotNull,
      );
      expect(
        SecurityUtils.validatePasswordConfirmation('abc123', 'abc123'),
        isNull,
      );
    });
  });

  group('SecurityUtils QR security', () {
    test('allows safe http(s) urls', () {
      expect(
        SecurityUtils.isValidQrHttpUrl('https://upgrade-e87b3.web.app/pair.html'),
        isTrue,
      );
      expect(
        SecurityUtils.isValidQrHttpUrl('www.example.com/pair'),
        isTrue,
      );
    });

    test('blocks dangerous schemes', () {
      expect(
        SecurityUtils.isBlockedQrScheme('javascript:alert(1)'),
        isTrue,
      );
      expect(
        SecurityUtils.isBlockedQrScheme('data:text/html,<script>'),
        isTrue,
      );
      expect(
        SecurityUtils.isBlockedQrScheme('file:///etc/passwd'),
        isTrue,
      );
    });

    test('normalizes www urls to https', () {
      expect(
        SecurityUtils.normalizeQrUrl('www.example.com'),
        'https://www.example.com',
      );
    });

    test('extracts pairing session id safely', () {
      expect(
        SecurityUtils.extractPairingSessionId('upgrade://pair?session=abc123'),
        'abc123',
      );
      expect(
        SecurityUtils.extractPairingSessionId('upgrade://pair?session=abc&x=1'),
        'abc',
      );
      expect(
        SecurityUtils.extractPairingSessionId('https://example.com'),
        isNull,
      );
    });
  });

  group('SecurityUtils invite email filtering', () {
    test('dedupes and drops invalid addresses', () {
      final filtered = SecurityUtils.filterInviteRecipientEmails([
        'a@test.com',
        'a@test.com',
        'invalid',
        '',
        '   ',
        'b@test.com',
      ]);

      expect(filtered, ['a@test.com', 'b@test.com']);
    });

    test('rejects addresses without valid domain', () {
      final filtered = SecurityUtils.filterInviteRecipientEmails([
        'user@localhost',
        'ok@school.edu',
      ]);

      expect(filtered, ['ok@school.edu']);
    });
  });

  group('SecurityUtils path and input hardening', () {
    test('rejects unsafe REST path segments', () {
      expect(SecurityUtils.isSafePathSegment('../admin'), isFalse);
      expect(SecurityUtils.isSafePathSegment('user/1'), isFalse);
      expect(SecurityUtils.isSafePathSegment('user?id=1'), isFalse);
      expect(SecurityUtils.isSafePathSegment('student_123'), isTrue);
    });

    test('sanitizes and caps display input length', () {
      final sanitized = SecurityUtils.sanitizeDisplayInput(
        '  Hello   world  ',
        maxLength: 20,
      );
      expect(sanitized, 'Hello world');

      final long = 'A' * 300;
      expect(
        SecurityUtils.sanitizeDisplayInput(long).length,
        SecurityUtils.maxDisplayFieldLength,
      );
    });

    test('redacts secrets for logs', () {
      expect(
        SecurityUtils.redactSecret('super-secret-token-1234'),
        '***1234',
      );
      expect(SecurityUtils.redactSecret(''), '[empty]');
    });

    test('rejects unsafe pairing session ids', () {
      expect(SecurityUtils.isSafePairingSessionId('valid_session-01'), isTrue);
      expect(SecurityUtils.isSafePairingSessionId('../sessions'), isFalse);
      expect(SecurityUtils.isSafePairingSessionId('id with space'), isFalse);
    });
  });
}
