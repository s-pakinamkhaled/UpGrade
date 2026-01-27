import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../widgets/app_logo.dart';
import '../widgets/gradient_card.dart';

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
  bool _isConnecting = false;
  String _pairingCode = '';
  String _deviceName = 'Desktop - Chrome';

  @override
  void initState() {
    super.initState();
    _generatePairingCode();
    _simulatePairing();
  }

  void _generatePairingCode() {
    final random = Random();
    _pairingCode = (100000 + random.nextInt(900000)).toString();
  }

  Future<void> _simulatePairing() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    setState(() => _isConnecting = true);

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _isPaired = true;
      _isConnecting = false;
    });
  }

  void _handleDisconnect() {
    setState(() {
      _isPaired = false;
      _pairingCode = '';
    });
    _generatePairingCode();
    _simulatePairing();
  }

  void _copyPairingCode() {
    Clipboard.setData(ClipboardData(text: _pairingCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Pairing code copied to clipboard'),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isFromSettings
          ? AppBar(title: const Text('Device Pairing'))
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.isFromSettings) ...[
                const SizedBox(height: 20),
                const Center(child: AppLogo.large()),
                const SizedBox(height: 40),
              ],

              const Text(
                'Pair Your Devices',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Connect mobile and desktop for seamless focus tracking',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.darkText.withOpacity(0.7),
                ),
              ),

              const SizedBox(height: 48),

              /// 🔥 QR CONTAINER (المشكلة كانت هنا واتصلحت)
              GradientCard(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Container(
                      width: 240,
                      height: 240,
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
                          : _isConnecting
                              ? _buildConnectingView()
                              : _buildQRCodeView(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              if (_isPaired) _buildPairedStatus(),

              if (!_isPaired && !_isConnecting) _buildGenerateButton(),

              if (!widget.isFromSettings && _isPaired)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed(
                      AppConstants.routeOnboarding,
                    );
                  },
                  child: const Text('Continue to Setup'),
                ),
            ],
          ),
        ),
      ),
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

  Widget _buildConnectingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text('Connecting...'),
      ],
    );
  }

  Widget _buildQRCodeView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CustomPaint(
          size: const Size(200, 200),
          painter: QRCodePainter(_pairingCode),
        ),
        const SizedBox(height: 12),
        Text(
          _pairingCode,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
        IconButton(
          onPressed: _copyPairingCode,
          icon: const Icon(Icons.copy),
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

  Widget _buildGenerateButton() {
    return ElevatedButton.icon(
      onPressed: () {
        _generatePairingCode();
        _simulatePairing();
      },
      icon: const Icon(Icons.refresh),
      label: const Text('Generate New Code'),
    );
  }
}

/// ================= QR Painter =================

class QRCodePainter extends CustomPainter {
  final String code;

  QRCodePainter(this.code);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.darkText;
    final cell = size.width / 25;

    for (int i = 0; i < 25; i++) {
      for (int j = 0; j < 25; j++) {
        if ((i * j + code.hashCode) % 3 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(i * cell, j * cell, cell, cell),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
