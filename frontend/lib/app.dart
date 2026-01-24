import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/login/login_screen.dart';

class UpgradeApp extends StatelessWidget {
  const UpgradeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Upgrade',
      theme: appTheme,
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

