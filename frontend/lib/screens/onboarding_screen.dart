import 'package:flutter/material.dart';

import '../core/post_auth_navigation.dart';
import '../core/theme.dart';

/// Four-step product onboarding (visual + copy aligned with marketing screens).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;

  static const Color _titleColor = Color(0xFF1E293B);
  static const Color _bodyColor = Color(0xFF64748B);
  static const Color _mutedNav = Color(0xFF94A3B8);
  static const Color _progressGrey = Color(0xFFE2E8F0);
  static const Color _checkGreen = Color(0xFF22C55E);
  static const Color _iconPinkTop = Color(0xFFEC4899);
  static const Color _iconPinkBottom = Color(0xFFF43F5E);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    });
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _finishOnboarding();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _finishOnboarding() async {
    if (!mounted) return;
    openWelcomeSyncChoiceAfterAuth(context);
  }

  LinearGradient _backgroundGradientForStep(int step) {
    switch (step) {
      case 0:
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF38BDF8),
            Color(0xFF7C3AED),
          ],
        );
      case 1:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B82F6),
            Color(0xFF5B21B6),
          ],
        );
      case 2:
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF1E3A5F),
            Color(0xFFA855F7),
          ],
        );
      default:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A2B4C),
            Color(0xFF6366F1),
          ],
        );
    }
  }

  BoxDecoration _iconDecorationForStep(int step) {
    switch (step) {
      case 0:
        return BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue,
              AppTheme.primaryBlue.withOpacity(0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withOpacity(0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case 1:
        return BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.secondaryPurple,
              Color(0xFF7C3AED),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.secondaryPurple.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case 2:
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_iconPinkTop, _iconPinkBottom],
          ),
          borderRadius: BorderRadius.all(Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Color(0x40EC4899),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        );
      default:
        return BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.mediumShadow,
        );
    }
  }

  IconData _iconForStep(int step) {
    switch (step) {
      case 0:
        return Icons.calendar_today_outlined;
      case 1:
        return Icons.psychology_outlined;
      case 2:
        return Icons.show_chart_rounded;
      default:
        return Icons.groups_outlined;
    }
  }

  Widget _buildProgressIndicator(int step) {
    final children = <Widget>[];
    for (var i = 0; i < 4; i++) {
      if (i > 0) children.add(const SizedBox(width: 10));
      if (i < step) {
        children.add(
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: _checkGreen,
              shape: BoxShape.circle,
            ),
          ),
        );
      } else if (i == step) {
        children.add(
          Container(
            width: 56,
            height: 10,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(999),
              boxShadow: AppTheme.softShadow,
            ),
          ),
        );
      } else {
        children.add(
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: _progressGrey,
              shape: BoxShape.circle,
            ),
          ),
        );
      }
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 20, color: _checkGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.35,
                color: _bodyColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientCta({
    required String label,
    required VoidCallback onPressed,
    bool showArrow = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppTheme.mediumShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (showArrow) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = _currentStep;
    const stepTotal = 4;
    final stepNumber = step + 1;

    final pages = <_OnboardPage>[
      _OnboardPage(
        title: 'Smart Study Planning',
        description:
            'AI-powered schedules that adapt to your workload, deadlines, and study habits in real-time.',
        bullets: const [
          'Adaptive to your behavior',
          'Google Classroom integration',
        ],
      ),
      _OnboardPage(
        title: 'AI Study Assistant',
        description:
            'Chat with your personalized AI assistant for daily planning, task prioritization, and study guidance.',
        bullets: const [
          'Conversational planning',
          'Real-time task updates',
        ],
      ),
      _OnboardPage(
        title: 'Burnout Prevention',
        description:
            'Get proactive warnings about workload risks and receive insights to maintain healthy study habits.',
        bullets: const [
          'Workload risk scoring',
          'Focus tracking across devices',
        ],
      ),
      _OnboardPage(
        title: 'Smart Group Study',
        description:
            'Automatically connect with classmates for collaborative learning and group study sessions.',
        bullets: const [
          'Auto group creation',
          'Easy collaboration',
        ],
        finalStep: true,
      ),
    ];

    final page = pages[step];
    final bg = _backgroundGradientForStep(step);

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            color: Colors.white,
            onPressed: () => Navigator.maybePop(context),
            tooltip: 'Back',
          ),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(gradient: bg),
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 88),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 32,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _buildProgressIndicator(step),
                                const SizedBox(height: 28),
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: _iconDecorationForStep(step),
                                  child: Icon(
                                    _iconForStep(step),
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  page.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: _titleColor,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  page.description,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.5,
                                    color: _bodyColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Align(
                                  alignment: Alignment.center,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 320),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        for (final b in page.bullets) _bullet(b),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    TextButton.icon(
                                      onPressed: step > 0 ? _prevStep : null,
                                      icon: Icon(
                                        Icons.arrow_back,
                                        size: 18,
                                        color: step > 0 ? _bodyColor : _mutedNav,
                                      ),
                                      label: Text(
                                        'Back',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: step > 0 ? _bodyColor : _mutedNav,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Center(
                                        child: TextButton(
                                          onPressed: _finishOnboarding,
                                          child: const Text(
                                            'Skip',
                                            style: TextStyle(
                                              color: _bodyColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: page.finalStep
                                              ? _gradientCta(
                                                  label: 'Get Started',
                                                  onPressed: _finishOnboarding,
                                                  showArrow: true,
                                                )
                                              : _gradientCta(
                                                  label: 'Next',
                                                  onPressed: _nextStep,
                                                  showArrow: true,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Step $stepNumber of $stepTotal',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.92),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 20,
                  bottom: 24,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Help'),
                            content: const Text(
                              'Use Next to learn about UpGrade, or Skip to open My courses.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Icon(
                          Icons.help_outline,
                          color: _titleColor,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardPage {
  final String title;
  final String description;
  final List<String> bullets;
  final bool finalStep;

  const _OnboardPage({
    required this.title,
    required this.description,
    required this.bullets,
    this.finalStep = false,
  });
}
