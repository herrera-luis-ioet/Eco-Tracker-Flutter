import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eco_tracker/src/shared/widgets/activity_input_form.dart';

void main() {
  group('ActivityInputForm Widget Tests', () {
    testWidgets('renders all form fields correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityInputForm(
              onSubmit: (
                {required String type,
                required double amount,
                String? description,
                String? category}) {},
            ),
          ),
        ),
      );

      // Verify all form fields are present
      expect(find.text('Activity Type'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('Description (Optional)'), findsOneWidget);
      expect(find.text('Category (Optional)'), findsOneWidget);
      expect(find.text('Submit Activity'), findsOneWidget);
    });

    testWidgets('initializes with provided values', (WidgetTester tester) async {
      const initialType = 'Recycling';
      const initialAmount = 10.5;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityInputForm(
              onSubmit: (
                {required String type,
                required double amount,
                String? description,
                String? category}) {},
              initialType: initialType,
              initialAmount: initialAmount,
            ),
          ),
        ),
      );

      expect(find.text(initialType), findsOneWidget);
      expect(find.text(initialAmount.toString()), findsOneWidget);
    });

    testWidgets('validates required fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityInputForm(
              onSubmit: (
                {required String type,
                required double amount,
                String? description,
                String? category}) {},
            ),
          ),
        ),
      );

      // Try to submit empty form
      await tester.tap(find.text('Submit Activity'));
      await tester.pumpAndSettle();

      // Verify error messages
      expect(find.text('Please enter an activity type'), findsOneWidget);
      expect(find.text('Please enter an amount'), findsOneWidget);
    });

    testWidgets('validates amount field for valid number', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityInputForm(
              onSubmit: (
                {required String type,
                required double amount,
                String? description,
                String? category}) {},
            ),
          ),
        ),
      );

      // Enter invalid amount
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), 'invalid');
      await tester.tap(find.text('Submit Activity'));
      await tester.pumpAndSettle();

      // Verify error message
      expect(find.text('Please enter a valid number'), findsOneWidget);
    });

    testWidgets('calls onSubmit with correct data', (WidgetTester tester) async {
      String? submittedType;
      double? submittedAmount;
      String? submittedDescription;
      String? submittedCategory;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityInputForm(
              onSubmit: (
                {required String type,
                required double amount,
                String? description,
                String? category}) {
                submittedType = type;
                submittedAmount = amount;
                submittedDescription = description;
                submittedCategory = category;
              },
            ),
          ),
        ),
      );

      // Fill form
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Activity Type'), 'Recycling');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Amount'), '10.5');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Description (Optional)'),
          'Test description');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Category (Optional)'), 'Household');

      // Submit form
      await tester.tap(find.text('Submit Activity'));
      await tester.pumpAndSettle();

      // Verify submitted data
      expect(submittedType, 'Recycling');
      expect(submittedAmount, 10.5);
      expect(submittedDescription, 'Test description');
      expect(submittedCategory, 'Household');
    });

    testWidgets('resets form after successful submission',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityInputForm(
              onSubmit: (
                {required String type,
                required double amount,
                String? description,
                String? category}) {},
            ),
          ),
        ),
      );

      // Fill form
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Activity Type'), 'Recycling');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Amount'), '10.5');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Description (Optional)'),
          'Test description');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Category (Optional)'), 'Household');

      // Submit form
      await tester.tap(find.text('Submit Activity'));
      await tester.pumpAndSettle();

      // Verify form is reset
      expect(find.text('Recycling'), findsNothing);
      expect(find.text('10.5'), findsNothing);
      expect(find.text('Test description'), findsNothing);
      expect(find.text('Household'), findsNothing);
    });
  });
}