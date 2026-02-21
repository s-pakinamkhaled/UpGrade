import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  // Student scopes: view your own courses and coursework (assignments + grades).
  // .students.readonly is for teachers; .me.readonly is for the signed-in student.
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/classroom.courses.readonly',
      'https://www.googleapis.com/auth/classroom.coursework.me.readonly',
    ],
  );

  static Future<String?> signInAndGetToken() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;

    final auth = await account.authentication;
    return auth.accessToken;
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
