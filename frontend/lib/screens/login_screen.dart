import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/constants.dart';
import '../widgets/app_logo.dart';
import '../services/firebase_auth_service.dart';
import '../services/api_service.dart';
import '../services/user_matching_profile_sync_service.dart';
import '../providers/classroom_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 🔥 Email / Password Login (Firebase Auth)
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await _authService.loginWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user == null) {
        throw Exception('Invalid email or password');
      }

      if (!mounted) return;
      await UserMatchingProfileSyncService.syncCurrentUserProfile(
        courses: context.read<ClassroomProvider>().courses,
        tasks: context.read<ClassroomProvider>().tasks,
      );

      Navigator.of(context).pushReplacementNamed(
        AppConstants.routeGoogleClassroomSync,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 🔥 Google Sign In (Firebase Auth)
  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await _authService.signInWithGoogle();

      if (user == null) {
        throw Exception('Google sign-in cancelled');
      }

      if (!mounted) return;
      await UserMatchingProfileSyncService.syncCurrentUserProfile(
        courses: context.read<ClassroomProvider>().courses,
        tasks: context.read<ClassroomProvider>().tasks,
      );

      Navigator.of(context).pushReplacementNamed(
        AppConstants.routeGoogleClassroomSync,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Google Sign-In failed';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: isDark
            ? BoxDecoration(color: theme.scaffoldBackgroundColor)
            : const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryBlue, AppTheme.secondaryPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surface
                        : Colors.white.withOpacity(0.94),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: AppTheme.strongShadow,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: AppLogo.large()),
                        const SizedBox(height: 24),
                        Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in to continue your study flow',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_error != null) ...[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.errorRed.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppTheme.errorRed,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: AppTheme.errorRed,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    Navigator.of(context).pushNamed(
                                      AppConstants.routeForgotPassword,
                                    );
                                  },
                            child: Text(
                              'Forgot password?',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _error != null
                                    ? Theme.of(context)
                                        .colorScheme
                                        .error
                                    : AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Sign in',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed:
                                _isLoading ? null : _handleGoogleLogin,
                            icon: const Icon(Icons.g_mobiledata, size: 28),
                            label: const Text('Continue with Google'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                color: AppTheme.darkText.withOpacity(0.7),
                              ),
                            ),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      Navigator.of(context).pushNamed(
                                        AppConstants.routeRegister,
                                      );
                                    },
                              child: const Text('Sign up'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () async {
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('test')
                                      .doc('check')
                                      .set({'connected': true});
                                  if (mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            '✅ Firestore Connected'),
                                        backgroundColor:
                                            AppTheme.successGreen,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  final String msg =
                                      e is FirebaseException &&
                                              e.code == 'permission-denied'
                                          ? 'Firestore: لا يوجد Permission للكتابة. '
                                              'القواعد على Firebase غالبًا مختلفة عن المشروع.\n\n'
                                              'الحل: من مجلد frontend شغّل:\n'
                                              'firebase deploy --only firestore\n\n'
                                              'أو من Console: Firestore → Rules والصق محتوى frontend/firestore.rules'
                                          : '❌ Firestore: $e';
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(msg),
                                      backgroundColor: AppTheme.errorRed,
                                      duration: const Duration(seconds: 8),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Test Firestore'),
                            ),
                            OutlinedButton(
                              onPressed: () async {
                                try {
                                  final message =
                                      await ApiService().testConnection();
                                  if (!mounted) return;
                                  final ok =
                                      message != 'Backend connection failed';
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          ok ? '✅ $message' : '❌ $message'),
                                      backgroundColor: ok
                                          ? AppTheme.successGreen
                                          : AppTheme.errorRed,
                                      duration:
                                          const Duration(seconds: 3),
                                    ),
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('❌ Backend: $e'),
                                        backgroundColor:
                                            AppTheme.errorRed,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text('Test Backend'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
