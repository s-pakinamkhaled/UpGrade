import 'package:firebase_auth/firebase_auth.dart';

/// User id stored in the FastAPI SQLite DB (tasks + in-app notifications).
/// Must match across task sync and notification fetch.
class BackendUserId {
  BackendUserId._();

  static String resolve() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? user?.email ?? 'guest_user';
  }
}
