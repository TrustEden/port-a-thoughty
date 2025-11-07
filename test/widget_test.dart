// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:porta_thoughty/main.dart';

void main() {
  testWidgets('Porta-Thoughty shell renders navigation tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PortaThoughtyApp());

    expect(find.text('Capture'), findsOneWidget);
    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('Docs'), findsOneWidget);

    // Switch to the queue tab.
    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();

    // Headline should mention the processing queue.
    expect(find.textContaining('Processing queue'), findsOneWidget);
  });
}
