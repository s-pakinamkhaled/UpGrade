import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/auth_form_probes.dart';
import '../helpers/widget_test_helpers.dart';

/// Auth screens require Firebase; this integration suite chains the same
/// validators used by login/register across a multi-step user input flow.
void main() {
  group('Auth validation flow (integration)', () {
    testWidgets('login rejects weak input then accepts valid credentials form',
        (tester) async {
      await tester.pumpWidget(const LoginFormProbe());
      await tester.pumpAndSettle();

      await tapButtonWithLabel(tester, 'Sign in');
      await tester.pumpAndSettle();
      expect(find.text('Please enter your email'), findsOneWidget);

      await enterTextByLabel(tester, 'Email', 'not-an-email');
      await enterTextByLabel(tester, 'Password', '123');
      await tapButtonWithLabel(tester, 'Sign in');
      await tester.pumpAndSettle();
      expect(find.text('Please enter a valid email'), findsOneWidget);
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'student@test.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'securePass1');
      await tapButtonWithLabel(tester, 'Sign in');
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsNothing);
      expect(find.text('Password must be at least 6 characters'), findsNothing);
    });

    testWidgets('register flow validates name, email, password, and confirmation',
        (tester) async {
      await tester.pumpWidget(const RegisterFormProbe());
      await tester.pumpAndSettle();

      await tapButtonWithLabel(tester, 'Create Account');
      await tester.pumpAndSettle();
      expect(find.text('Enter your name'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Pakinam');
      await tester.enterText(find.byType(TextFormField).at(1), 'bad-email');
      await tester.enterText(find.byType(TextFormField).at(2), 'short');
      await tester.enterText(find.byType(TextFormField).at(3), 'different');
      await tapButtonWithLabel(tester, 'Create Account');
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);
      expect(find.text('Weak password'), findsOneWidget);
      expect(find.text('Passwords mismatch'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(1), 'pakinam@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'SecurePass1!');
      await tester.enterText(find.byType(TextFormField).at(3), 'SecurePass1!');
      await tapButtonWithLabel(tester, 'Create Account');
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsNothing);
      expect(find.text('Passwords mismatch'), findsNothing);
    });
  });
}
