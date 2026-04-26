import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme.dart';
import '../core/constants.dart';
import '../widgets/gradient_card.dart';
import '../widgets/upgrade_page_shell.dart';

class DevicePairingScreen extends StatefulWidget {
  final bool isFromSettings;

  const DevicePairingScreen({
    super.key,
    this.isFromSettings = false,
  });

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  bool _isPaired = false;
  bool _isCreatingSession = false;
  String? sessionId;
  String _deviceName = 'Desktop - Chrome';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _pairingSubscription;

  @override
  void initState() {
    super.initState();
    createSession();
  }

  @override
  void dispose() {
    _pairingSubscription?.cancel();
    super.dispose();
  }

  Future<void> createSession() async {
    if (_isCreatingSession) return;
    _isCreatingSession = true;
    _pairingSubscription?.cancel();
    _pairingSubscription = null;
    try {
      final auth = FirebaseAuth.instance;
      var user = auth.currentUser;
      if (user == null) {
        user = await auth.authStateChanges().first.timeout(
          const Duration(seconds: 4),
          onTimeout: () => null,
        );
      }
      final doc = await FirebaseFirestore.instance
          .collection('pairing_sessions')
          .add({
        'paired': false,
        'device': null,
        'createdBy': user?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() => sessionId = doc.id);
      listenForPairing();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create session: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _isCreatingSession = false;
    }
  }

  void listenForPairing() {
    if (sessionId == null) return;
    _pairingSubscription = FirebaseFirestore.instance
        .collection('pairing_sessions')
        .doc(sessionId)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      final data = doc.data();
      if (data != null && data['paired'] == true) {
        setState(() {
          _isPaired = true;
          _deviceName = data['device'] ?? 'Mobile device';
        });
        // Laptop website unlocks: open dashboard when mobile confirms pairing
        if (!widget.isFromSettings) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            Navigator.of(context).pushReplacementNamed(
              AppConstants.routeOnboarding,
            );
          });
        }
      }
    });
  }

  void _skipPairing() {
    if (widget.isFromSettings) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      Navigator.of(context).pushReplacementNamed(
        AppConstants.routeOnboarding,
      );
    }
  }

  Future<void> _handleDisconnect() async {
    if (sessionId != null) {
      await FirebaseFirestore.instance
          .collection('pairing_sessions')
          .doc(sessionId)
          .delete();
    }
    _pairingSubscription?.cancel();
    _pairingSubscription = null;
    setState(() {
      _isPaired = false;
      sessionId = null;
    });
    createSession();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFromSettings) {
      // داخل الإعدادات: نستخدم الشكل العادي مع AppBar للحفاظ على تجربة المستخدم
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.maybePop(context),
            tooltip: 'Back',
          ),
          title: const Text('Device Pairing'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildBody(),
        ),
      );
    }

    // أثناء الـ onboarding / فتح الويب: نستخدم الـ shell الجديد
    return UpGradePageShell(
      title: 'Connect Desktop',
      subtitle: 'Scan this QR from your UpGrade mobile app',
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GradientCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                    width: 2,
                  ),
                  boxShadow: AppTheme.softShadow,
                ),
                child: _isPaired
                    ? _buildPairedView()
                    : sessionId == null
                        ? _buildLoadingView()
                        : _buildQRCodeView(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        if (_isPaired) _buildPairedStatus(),
        if (!_isPaired && sessionId != null) ...[
          _buildNewSessionButton(),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _skipPairing,
            icon: const Icon(Icons.skip_next, size: 20),
            label: const Text('Skip Session'),
          ),
        ],
        if (!_isPaired && sessionId == null) ...[
          ElevatedButton.icon(
            onPressed: createSession,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Session'),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _skipPairing,
            icon: const Icon(Icons.skip_next, size: 20),
            label: const Text('Skip Session'),
          ),
        ],
        if (!widget.isFromSettings && _isPaired)
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              Navigator.of(context).pushReplacementNamed(
                AppConstants.routeOnboarding,
              );
            },
            child: const Text('Continue to Setup'),
          ),
      ],
    );
  }

  /// ================= Widgets =================

  Widget _buildPairedView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.check_circle, size: 64, color: AppTheme.successGreen),
        SizedBox(height: 12),
        Text(
          'Connected',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text('Creating session...'),
      ],
    );
  }

  Widget _buildQRCodeView() {
    final link = 'upgrade://pair?session=$sessionId';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        QrImageView(
          data: link,
          size: 180,
          backgroundColor: AppTheme.white,
        ),
        const SizedBox(height: 8),
        Text(
          'In UpGrade app: Menu → Connect Desktop',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.darkText.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Then scan this QR with your phone',
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.darkText.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildPairedStatus() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.successGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.check, color: AppTheme.successGreen),
          const SizedBox(width: 12),
          Expanded(child: Text(_deviceName)),
          IconButton(
            onPressed: _handleDisconnect,
            icon: const Icon(Icons.close),
            color: AppTheme.errorRed,
          ),
        ],
      ),
    );
  }

  Widget _buildNewSessionButton() {
    return ElevatedButton.icon(
      onPressed: sessionId == null ? null : () => _handleDisconnect(),
      icon: const Icon(Icons.refresh),
      label: const Text('New session'),
    );
  }
}
