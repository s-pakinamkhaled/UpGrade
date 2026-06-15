import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:upgrade/providers/classroom_provider.dart';

/// Wraps auth screens with the minimum provider tree needed for widget tests.
Widget wrapAuthTestApp(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ClassroomProvider()),
    ],
    child: MaterialApp(home: child),
  );
}

/// Taps the first button whose label contains [label].
Future<void> tapButtonWithLabel(WidgetTester tester, String label) async {
  final button = find.widgetWithText(ElevatedButton, label);
  expect(button, findsOneWidget);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// Enters text into a field located by [labelText].
Future<void> enterTextByLabel(
  WidgetTester tester,
  String labelText,
  String value,
) async {
  final field = find.widgetWithText(TextFormField, labelText);
  if (field.evaluate().isEmpty) {
    await tester.enterText(find.byType(TextFormField).at(0), value);
    return;
  }
  await tester.enterText(field, value);
}
