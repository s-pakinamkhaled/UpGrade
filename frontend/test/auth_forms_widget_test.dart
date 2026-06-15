import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_form_probes.dart';

void main() {
  group('Login form widget validation (SecurityUtils)', () {
    testWidgets('shows email error for invalid address', (tester) async {
      await tester.pumpWidget(const LoginFormProbe());

      await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
      await tester.enterText(find.byType(TextFormField).at(1), '123456');
      await tester.tap(find.text('Sign in'));
      await tester.pump();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('shows password error when too short', (tester) async {
      await tester.pumpWidget(const LoginFormProbe());

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'pakinam@test.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), '123');
      await tester.tap(find.text('Sign in'));
      await tester.pump();

      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );
    });

    testWidgets('shows required email message when empty', (tester) async {
      await tester.pumpWidget(const LoginFormProbe());

      await tester.tap(find.text('Sign in'));
      await tester.pump();

      expect(find.text('Please enter your email'), findsOneWidget);
    });
  });

  group('Register form widget validation (SecurityUtils)', () {
    testWidgets('shows password mismatch error', (tester) async {
      await tester.pumpWidget(const RegisterFormProbe());

      await tester.enterText(find.byType(TextFormField).at(0), 'Pakinam');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'pakinam@test.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'secret1');
      await tester.enterText(find.byType(TextFormField).at(3), 'different');

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(find.text('Passwords mismatch'), findsOneWidget);
    });

    testWidgets('rejects malformed email', (tester) async {
      await tester.pumpWidget(const RegisterFormProbe());

      await tester.enterText(find.byType(TextFormField).at(0), 'Pakinam');
      await tester.enterText(find.byType(TextFormField).at(1), 'bad-email');
      await tester.enterText(find.byType(TextFormField).at(2), 'secret1');
      await tester.enterText(find.byType(TextFormField).at(3), 'secret1');

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('requires full name', (tester) async {
      await tester.pumpWidget(const RegisterFormProbe());

      await tester.enterText(
        find.byType(TextFormField).at(1),
        'pakinam@test.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'secret1');
      await tester.enterText(find.byType(TextFormField).at(3), 'secret1');

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(find.text('Enter your name'), findsOneWidget);
    });
  });
}
