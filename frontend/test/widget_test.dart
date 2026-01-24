import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const UpgradeApp());
    expect(find.text('Upgrade'), findsOneWidget);
  });
}

