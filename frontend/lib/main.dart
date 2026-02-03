import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'core/constants.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/google_classroom_sync_screen.dart';
import 'screens/device_pairing_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UpGrade',

      
      initialRoute: AppConstants.routeLogin,

       routes: {
        AppConstants.routeLogin: (_) => const LoginScreen(),
        AppConstants.routeRegister: (_) => const RegisterScreen(),
        AppConstants.routeGoogleClassroomSync: (_) =>
            const GoogleClassroomSyncScreen(),

        
        AppConstants.routeDevicePairing: (_) =>
            const DevicePairingScreen(),

        
        AppConstants.routeOnboarding: (_) =>
            const OnboardingScreen(),
        AppConstants.routeHome: (_) => const HomeScreen(),
      },
    );
  }
}
