import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Web → popup. Android/iOS → GoogleSignIn.
  Future<User?> signInWithGoogle() async {
    if (kIsWeb) {
      // Web: use Firebase popup (no google_sign_in package needed on web)
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      final userCredential =
          await _auth.signInWithPopup(googleProvider);
      return userCredential.user;
    } else {
      // Mobile: Android / iOS
      final GoogleSignInAccount? googleUser =
          await GoogleSignIn().signIn();

      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _auth.signInWithCredential(credential);

      return userCredential.user;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  Future<User?> register(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user;
  }

  Future<User?> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  static String getAuthErrorMessage(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'This account already exists. Sign in or use another email.';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';
        case 'user-not-found':
          return 'No account found. Check your email or create an account.';
        case 'wrong-password':
          return 'Wrong password. Try again.';
        case 'invalid-email':
          return 'Invalid email format.';
        case 'invalid-credential':
          return 'Invalid email or password.';
        case 'operation-not-allowed':
          return 'Email sign-in is not enabled. Check project settings.';
        case 'network-request-failed':
          return 'Network error. Check your connection.';
        default:
          return e.message ?? 'Something went wrong. Try again.';
      }
    }
    return e.toString().replaceFirst('Exception:', '').trim();
  }
}
