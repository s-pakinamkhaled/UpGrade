import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../widgets/app_logo.dart';

/// Branded launch screen shown once when the app or web client opens.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Duration _minimumDisplay = Duration(milliseconds: 2400);

  late final AnimationController _introController;
  late final AnimationController _ambientController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _titleSlide;
  late final Animation<double> _titleFade;
  late final Animation<double> _taglineFade;
  late final Animation<double> _glowStrength;
  late final Animation<double> _shimmer;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.72, curve: Curves.elasticOut),
      ),
    );

    _logoFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );

    _titleSlide = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.28, 0.68, curve: Curves.easeOutCubic),
      ),
    );

    _titleFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.28, 0.62, curve: Curves.easeOut),
    );

    _taglineFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.45, 0.78, curve: Curves.easeOut),
    );

    _glowStrength = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.15, 0.85, curve: Curves.easeInOut),
      ),
    );

    _shimmer = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
    );

    _scheduleNavigation();
  }

  Future<void> _scheduleNavigation() async {
    await Future.wait([
      _introController.forward(),
      Future<void>.delayed(_minimumDisplay),
    ]);
    await _goToLogin();
  }

  Future<void> _goToLogin() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(AppConstants.routeLogin);
  }

  @override
  void dispose() {
    _introController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_introController, _ambientController]),
        builder: (context, child) {
          final drift = _ambientController.value;
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1D4ED8),
                  Color(0xFF6366F1),
                  Color(0xFF7C3AED),
                ],
                stops: [0.0, 0.52, 1.0],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _AmbientOrb(
                  top: -80 + drift * 24,
                  left: -60,
                  size: 220,
                  opacity: 0.22,
                ),
                _AmbientOrb(
                  bottom: -100 + drift * 18,
                  right: -40,
                  size: 260,
                  opacity: 0.18,
                ),
                _AmbientOrb(
                  top: 120 + drift * 12,
                  right: 40,
                  size: 120,
                  opacity: 0.14,
                ),
                SafeArea(
                  child: Column(
                    children: [
                      const Spacer(flex: 3),
                      FadeTransition(
                        opacity: _logoFade,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: _LogoHero(
                            glowStrength: _glowStrength.value,
                            shimmer: _shimmer.value,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      FadeTransition(
                        opacity: _titleFade,
                        child: Transform.translate(
                          offset: Offset(0, _titleSlide.value),
                          child: const Text(
                            AppConstants.appName,
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -1.2,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FadeTransition(
                        opacity: _taglineFade,
                        child: Text(
                          AppConstants.appTagline,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.88),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const Spacer(flex: 2),
                      FadeTransition(
                        opacity: _taglineFade,
                        child: _LoadingDots(progress: _introController.value),
                      ),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LogoHero extends StatelessWidget {
  const _LogoHero({
    required this.glowStrength,
    required this.shimmer,
  });

  final double glowStrength;
  final double shimmer;

  @override
  Widget build(BuildContext context) {
    const logoSize = 112.0;

    return SizedBox(
      width: logoSize + 56,
      height: logoSize + 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: logoSize + 40 * glowStrength,
            height: logoSize + 40 * glowStrength,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.28 * glowStrength),
                  blurRadius: 36 * glowStrength,
                  spreadRadius: 6 * glowStrength,
                ),
                BoxShadow(
                  color: AppTheme.secondaryPurple.withOpacity(0.45 * glowStrength),
                  blurRadius: 48 * glowStrength,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Transform.rotate(
            angle: shimmer * math.pi * 2,
            child: Container(
              width: logoSize + 28,
              height: logoSize + 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.18 + shimmer * 0.12),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const AppLogo(
            size: logoSize,
            showShadow: true,
          ),
        ],
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({
    this.top,
    this.left,
    this.bottom,
    this.right,
    required this.size,
    required this.opacity,
  });

  final double? top;
  final double? left;
  final double? bottom;
  final double? right;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      bottom: bottom,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withOpacity(opacity),
              Colors.white.withOpacity(0),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final phase = ((progress * 3) - index).clamp(0.0, 1.0);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 8 + phase * 4,
          height: 8 + phase * 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.35 + phase * 0.55),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
