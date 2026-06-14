import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/core/security_utils.dart';

/// Lightweight login form used in widget tests — same validators as [LoginScreen].
class LoginFormProbe extends StatefulWidget {
  const LoginFormProbe({super.key});

  @override
  State<LoginFormProbe> createState() => _LoginFormProbeState();
}

class _LoginFormProbeState extends State<LoginFormProbe> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                validator: SecurityUtils.validateLoginEmail,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: SecurityUtils.validatePassword,
              ),
              ElevatedButton(
                onPressed: () => _formKey.currentState!.validate(),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lightweight register form — same validators as [RegisterScreen].
class RegisterFormProbe extends StatefulWidget {
  const RegisterFormProbe({super.key});

  @override
  State<RegisterFormProbe> createState() => _RegisterFormProbeState();
}

class _RegisterFormProbeState extends State<RegisterFormProbe> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: SecurityUtils.validateNonEmptyName,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => SecurityUtils.validateLoginEmail(v),
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: SecurityUtils.validateRegisterPassword,
              ),
              TextFormField(
                decoration:
                    const InputDecoration(labelText: 'Confirm Password'),
                obscureText: true,
                validator: (v) => SecurityUtils.validatePasswordConfirmation(
                  _passwordController.text,
                  v,
                ),
              ),
              ElevatedButton(
                onPressed: () => _formKey.currentState!.validate(),
                child: const Text('Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
