import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Result of Google sign-in via Firebase (includes [isNewUser] when [additionalUserInfo] is present).
class GoogleSignInAuthResult {
  const GoogleSignInAuthResult({
    required this.user,
    required this.isNewUser,
  });

  final User user;
  final bool isNewUser;
}

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Email login
  Future<User?> loginWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  /// Email signup
  Future<User?> signUpWithEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  /// Google sign-in / sign-up. [GoogleSignInAuthResult.isNewUser] is true the first time this Google account is linked to Firebase.
  Future<GoogleSignInAuthResult?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    final user = userCred.user;
    if (user == null) return null;
    final isNewUser = userCred.additionalUserInfo?.isNewUser ?? false;
    return GoogleSignInAuthResult(user: user, isNewUser: isNewUser);
  }

  Stream<User?> authState() => _auth.authStateChanges();

  /// Send password reset email. User receives a link to reset password.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> logout() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }
}
