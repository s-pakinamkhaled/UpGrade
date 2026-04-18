import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class GoogleAuthService {
  static const List<String> classroomScopes = [
    'https://www.googleapis.com/auth/classroom.courses.readonly',
    'https://www.googleapis.com/auth/classroom.coursework.me.readonly',
    'https://www.googleapis.com/auth/classroom.student-submissions.me.readonly',
  ];

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: classroomScopes,
  );

  /// Access the underlying GoogleSignIn instance (for token refresh, etc.)
  static GoogleSignIn get instance => _googleSignIn;

  static Future<String?> signInAndGetToken() async {
    try {
      GoogleSignInAccount? account = _googleSignIn.currentUser;
      if (account == null) {
        if (kIsWeb) {
          // Web uses GIS renderButton flow; avoid deprecated popup signIn().
          account = await _googleSignIn.signInSilently();
        } else {
          account = await _googleSignIn.signIn();
        }
      }
      if (account == null) {
        print('[GoogleAuth] Sign-in cancelled by user');
        return null;
      }
      print('[GoogleAuth] Signed in as: ${account.email}');

      if (!kIsWeb) {
        final hasScopes = await _googleSignIn.canAccessScopes(classroomScopes);
        if (!hasScopes) {
          print('[GoogleAuth] Missing Classroom scopes. Requesting additional permissions...');
          final granted = await _googleSignIn.requestScopes(classroomScopes);
          if (!granted) {
            print('[GoogleAuth] Scope request declined.');
            await _googleSignIn.disconnect();
            account = await _googleSignIn.signIn();
            if (account == null) return null;
          }
        }
      } else {
        print('[GoogleAuth] Web: skipping canAccessScopes/requestScopes (unreliable on web; token is source of truth).');
      }

      // Get the authentication tokens
      final auth = await account.authentication;
      final token = auth.accessToken;
      final idToken = auth.idToken;
      
      print('[GoogleAuth] accessToken is ${token != null ? "present (${token.length} chars)" : "NULL"}');
      print('[GoogleAuth] idToken is ${idToken != null ? "present" : "NULL"}');

      if (token == null) {
        print('[GoogleAuth] WARNING: accessToken is null — trying to refresh...');
        // Force re-authentication to get a fresh token
        final reAuth = await account.authentication;
        final refreshedToken = reAuth.accessToken;
        print('[GoogleAuth] After refresh: accessToken is ${refreshedToken != null ? "present" : "still NULL"}');
        return refreshedToken;
      }
      
      return token;
    } catch (e) {
      print('[GoogleAuth] Sign-in error: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
