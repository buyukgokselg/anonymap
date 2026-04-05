import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Flutter test binding works', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Placeholder()),
      ),
    );
    expect(find.byType(Placeholder), findsOneWidget);
  });
}
