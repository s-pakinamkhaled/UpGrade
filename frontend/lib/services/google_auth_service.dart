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

  /// Interactive Google sign-in with Classroom scopes (always shows account UI if needed).
  static Future<String?> signInAndGetToken() =>
      signInForClassroom(trySilentFirst: false);

  /// Obtain an access token for Classroom APIs.
  ///
  /// Production flow: optional [signInSilently] first (e.g. Firebase user linked with
  /// Google), then interactive [signIn]. On web, silent sign-in often returns an
  /// account without a usable `accessToken` — we then [signOut] and run a fresh
  /// interactive sign-in so scopes + token are aligned with this [GoogleSignIn] instance.
  static Future<String?> signInForClassroom({
    bool trySilentFirst = false,
  }) async {
    try {
      GoogleSignInAccount? account;

      if (trySilentFirst) {
        try {
          account = await _googleSignIn.signInSilently(suppressErrors: true);
        } catch (e) {
          debugPrint('[GoogleAuth] silent error: $e');
        }
      }

      account ??= await _googleSignIn.signIn();
      if (account == null) {
        debugPrint('[GoogleAuth] Sign-in cancelled by user');
        return null;
      }

      debugPrint('[GoogleAuth] Signed in as: ${account.email}');

      var auth = await account.authentication;
      var token = auth.accessToken;
      debugPrint(
        '[GoogleAuth] accessToken is ${token != null ? "present (${token.length} chars)" : "NULL"}',
      );
      debugPrint(
        '[GoogleAuth] idToken is ${auth.idToken != null ? "present" : "NULL"}',
      );

      if (token == null) {
        debugPrint(
          '[GoogleAuth] accessToken null after sign-in → signOut + interactive retry',
        );
        await _googleSignIn.signOut();

        final newAccount = await _googleSignIn.signIn();
        if (newAccount == null) {
          debugPrint('[GoogleAuth] Interactive retry cancelled');
          return null;
        }
        debugPrint('[GoogleAuth] Retry signed in as: ${newAccount.email}');
        final newAuth = await newAccount.authentication;
        token = newAuth.accessToken;
        debugPrint(
          '[GoogleAuth] after retry accessToken is ${token != null ? "present (${token.length} chars)" : "NULL"}',
        );
      }

      return token;
    } catch (e) {
      debugPrint('[GoogleAuth] error: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
