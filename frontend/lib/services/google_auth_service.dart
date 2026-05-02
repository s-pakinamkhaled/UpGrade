import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/classroom.courses.readonly',
      'https://www.googleapis.com/auth/classroom.coursework.me.readonly',
      'https://www.googleapis.com/auth/classroom.student-submissions.me.readonly',
    ],
  );

  /// Access the underlying GoogleSignIn instance (for token refresh, etc.)
  static GoogleSignIn get instance => _googleSignIn;

  static Future<String?> signInAndGetToken() async {
    try {
      // On web, signIn() triggers the popup and returns the account
      final account = await _googleSignIn.signIn();
      if (account == null) {
        debugPrint('[GoogleAuth] Sign-in cancelled by user');
        return null;
      }
      debugPrint('[GoogleAuth] Signed in as: ${account.email}');

      // Get the authentication tokens
      final auth = await account.authentication;
      final token = auth.accessToken;
      final idToken = auth.idToken;

      debugPrint(
          '[GoogleAuth] accessToken is ${token != null ? "present (${token.length} chars)" : "NULL"}');
      debugPrint(
          '[GoogleAuth] idToken is ${idToken != null ? "present" : "NULL"}');

      if (token == null) {
        debugPrint(
            '[GoogleAuth] WARNING: accessToken is null — trying to refresh...');
        // Force re-authentication to get a fresh token
        final reAuth = await account.authentication;
        final refreshedToken = reAuth.accessToken;
        debugPrint(
            '[GoogleAuth] After refresh: accessToken is ${refreshedToken != null ? "present" : "still NULL"}');
        return refreshedToken;
      }

      return token;
    } catch (e) {
      debugPrint('[GoogleAuth] Sign-in error: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
