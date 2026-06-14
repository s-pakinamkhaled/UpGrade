import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/theme.dart';
import '../services/device_pairing_storage_service.dart';

/// الموبايل يقرأ QR → يأخذ اللينك → يفتحه في المتصفح.
/// إذا القيمة مش URL يعرض "Invalid QR".
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _hasScanned = false;

  bool _isValidUrl(String value) {
    value = value.trim();
    if (value.isEmpty) return false;
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('www.');
  }

  String _normalizeUrl(String value) {
    value = value.trim();
    if (value.startsWith('www.')) return 'https://$value';
    return value;
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.tryParse(_normalizeUrl(url));
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// استخراج sessionId من QR pairing (مثل upgrade://pair?session=xxx)
  String? _extractSessionId(String value) {
    if (!value.contains('session=')) return null;
    final uri = Uri.tryParse(value);
    if (uri != null && uri.queryParameters['session'] != null) {
      return uri.queryParameters['session'];
    }
    final after = value.split('session=').last;
    return after.split('&').first.trim();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_hasScanned) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? qrValue = barcodes.first.rawValue;
    if (qrValue == null || qrValue.isEmpty) return;

    _hasScanned = true;

    // pairing QR: upgrade://pair?session=xxx → تحديث Firestore
    final sessionId = _extractSessionId(qrValue);
    if (sessionId != null && sessionId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('pairing_sessions')
            .doc(sessionId)
            .update({
          'paired': true,
          'device': 'Mobile device',
        });
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await DevicePairingStorageService.setPaired(
            uid: uid,
            paired: true,
            deviceName: 'Mobile device',
          );
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Paired successfully'),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pairing failed: $e'),
              backgroundColor: AppTheme.errorRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _hasScanned = false);
        }
      }
      return;
    }

    if (_isValidUrl(qrValue)) {
      await _openInBrowser(qrValue);
      if (mounted) Navigator.of(context).pop();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Invalid QR – not a valid URL'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _hasScanned = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        title: const Text('Connect Desktop'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (_, state, __) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off);
                  case TorchState.on:
                    return const Icon(Icons.flash_on);
                  default:
                    return const Icon(Icons.flash_auto);
                }
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryBlue, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Text(
              'Pairing QR from your laptop, or any valid web link',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 14,
                shadows: [
                  Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
