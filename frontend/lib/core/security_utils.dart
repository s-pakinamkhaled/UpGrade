/// Shared input validation and security helpers used across auth, QR pairing,
/// and notification flows.
class SecurityUtils {
  SecurityUtils._();

  static const int defaultPasswordMinLength = 6;
  static const int maxDisplayFieldLength = 200;

  /// Basic email validation used by login/register/forgot-password flows.
  static bool isValidEmail(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 254) return false;
    if (trimmed.contains(' ')) return false;

    final atIndex = trimmed.indexOf('@');
    if (atIndex <= 0 || atIndex != trimmed.lastIndexOf('@')) return false;

    final local = trimmed.substring(0, atIndex);
    final domain = trimmed.substring(atIndex + 1);
    if (local.isEmpty || domain.isEmpty) return false;
    if (!domain.contains('.')) return false;
    if (domain.startsWith('.') || domain.endsWith('.')) return false;
    if (domain.split('.').last.length < 2) return false;

    return true;
  }

  static String? validateLoginEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    if (!isValidEmail(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? validatePassword(
    String? value, {
    int minLength = defaultPasswordMinLength,
  }) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    return null;
  }

  static String? validateRegisterPassword(String? value) {
    if (value == null || value.length < defaultPasswordMinLength) {
      return 'Weak password';
    }
    return null;
  }

  static String? validatePasswordConfirmation(
    String? password,
    String? confirmation,
  ) {
    if (confirmation != password) {
      return 'Passwords mismatch';
    }
    return null;
  }

  static String? validateNonEmptyName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your name';
    }
    return null;
  }

  /// Only http(s) and www. URLs are opened from scanned QR codes.
  static bool isValidQrHttpUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('www.');
  }

  static String normalizeQrUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('www.')) return 'https://$trimmed';
    return trimmed;
  }

  /// Extract pairing session id from `upgrade://pair?session=...` QR payloads.
  static String? extractPairingSessionId(String value) {
    if (!value.contains('session=')) return null;

    final uri = Uri.tryParse(value);
    if (uri != null && uri.queryParameters['session'] != null) {
      final session = uri.queryParameters['session']!.trim();
      return session.isEmpty ? null : session;
    }

    final after = value.split('session=').last;
    final session = after.split('&').first.trim();
    return session.isEmpty ? null : session;
  }

  /// Reject javascript/data URLs that must never be opened from QR scans.
  static bool isBlockedQrScheme(String value) {
    final lower = value.trim().toLowerCase();
    return lower.startsWith('javascript:') ||
        lower.startsWith('data:') ||
        lower.startsWith('file:');
  }

  /// Filters invite recipients: trim, dedupe, require `@`, drop blanks.
  static List<String> filterInviteRecipientEmails(List<String> emails) {
    return emails
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.contains('@') && isValidEmail(e))
        .toSet()
        .toList();
  }

  /// User ids and task ids used in REST paths must not contain traversal chars.
  static bool isSafePathSegment(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 128) return false;
    if (trimmed.contains('/') ||
        trimmed.contains('\\') ||
        trimmed.contains('..') ||
        trimmed.contains('?') ||
        trimmed.contains('#')) {
      return false;
    }
    return true;
  }

  /// Firestore pairing session document ids (alphanumeric, dash, underscore only).
  static final RegExp _pairingSessionIdPattern =
      RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  static bool isSafePairingSessionId(String? value) {
    if (value == null) return false;
    return _pairingSessionIdPattern.hasMatch(value.trim());
  }

  /// Trim and cap free-text fields before sending to backend or Firestore.
  static String sanitizeDisplayInput(
    String input, {
    int maxLength = maxDisplayFieldLength,
  }) {
    final collapsed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.length <= maxLength) return collapsed;
    return collapsed.substring(0, maxLength);
  }

  /// Redact sensitive values for logs (tokens, passwords).
  static String redactSecret(String? value, {int visibleTail = 4}) {
    if (value == null || value.isEmpty) return '[empty]';
    if (value.length <= visibleTail) return '***';
    return '***${value.substring(value.length - visibleTail)}';
  }
}
