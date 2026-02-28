import 'package:google_sign_in/google_sign_in.dart';

/// Google Sign-In for Classroom API (returns access token for sync).
class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/classroom.courses.readonly',
      'https://www.googleapis.com/auth/classroom.coursework.me',
      'https://www.googleapis.com/auth/classroom.student-submissions.me.readonly',
    ],
  );

  static Future<String?> signInAndGetToken() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;

    final auth = await account.authentication;
    return auth.accessToken;
  }
}
