import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/classroom_provider.dart';

/// Keeps [ClassroomProvider] in sync with [FirebaseAuth] so cached courses never
/// leak across user sessions.
class ClassroomAuthBinder extends StatefulWidget {
  final Widget child;

  const ClassroomAuthBinder({super.key, required this.child});

  @override
  State<ClassroomAuthBinder> createState() => _ClassroomAuthBinderState();
}

class _ClassroomAuthBinderState extends State<ClassroomAuthBinder> {
  StreamSubscription<User?>? _authSub;
  String? _lastUid;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onAuthChanged(FirebaseAuth.instance.currentUser);
    });
  }

  Future<void> _onAuthChanged(User? user) async {
    if (!mounted) return;
    final provider = context.read<ClassroomProvider>();
    final nextUid = user?.uid;

    if (nextUid == _lastUid) return;
    _lastUid = nextUid;

    if (nextUid == null) {
      await provider.clearUserData();
      return;
    }

    await provider.loadForCurrentUser();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
