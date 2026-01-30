// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:sticksy/app.dart';
import 'package:sticksy/core/config/env.dart';

void main() {
  testWidgets('App renders env gate', (WidgetTester tester) async {
    final envResult = EnvLoadResult(
      config: null,
      missingKeys: const ['OPENROUTER_MODEL'],
      errorMessage: 'Missing env',
    );
    await tester.pumpWidget(SticksyApp(envResult: envResult));
    expect(find.text('Sticksy'), findsWidgets);
  });
}
