import 'package:flutter/material.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';

Widget buildGoogleWebSignInButton() {
  final platform = GoogleSignInPlatform.instance;
  if (platform is! GoogleSignInPlugin) {
    return const Text('Google web sign-in is unavailable');
  }

  return SizedBox(
    width: double.infinity,
    child: platform.renderButton(
      configuration: GSIButtonConfiguration(
        theme: GSIButtonTheme.outline,
        size: GSIButtonSize.large,
        shape: GSIButtonShape.pill,
        text: GSIButtonText.continueWith,
      ),
    ),
  );
}
