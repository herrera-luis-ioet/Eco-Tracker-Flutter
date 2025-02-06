import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eco_tracker/src/app.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  group('App', () {
    testWidgets('renders correctly', (WidgetTester tester) async {
      // Build our app and trigger a frame
      await tester.pumpWidget(const App());

      // Verify that the app renders without errors
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    // TODO: Add more widget tests for app navigation and state management
  });
}