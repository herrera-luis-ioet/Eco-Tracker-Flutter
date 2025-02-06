import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:eco_tracker/src/core/models/eco_activity.dart';
import 'package:eco_tracker/src/shared/widgets/eco_activity_card.dart';

void main() {
  group('EcoActivityCard Widget Tests', () {
    late EcoActivity testActivity;
    
    setUp(() {
      testActivity = EcoActivity(
        id: 'test-id',
        userId: 'user-1',
        type: 'Recycling',
        amount: 10.5,
        date: DateTime(2023, 12, 1),
        description: 'Test description',
        category: 'Household',
      );
    });

    testWidgets('renders all activity information correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EcoActivityCard(activity: testActivity),
          ),
        ),
      );

      // Verify activity type is displayed and uppercase
      expect(find.text('RECYCLING'), findsOneWidget);
      
      // Verify date is formatted correctly
      final dateFormat = DateFormat('MMM d, y');
      expect(find.text(dateFormat.format(testActivity.date)), findsOneWidget);
      
      // Verify description is displayed
      expect(find.text(testActivity.description!), findsOneWidget);
      
      // Verify category chip is displayed
      expect(find.text(testActivity.category!), findsOneWidget);
      
      // Verify amount is displayed with correct format
      expect(find.text('${testActivity.amount.toStringAsFixed(2)} units'), findsOneWidget);
    });

    testWidgets('handles missing optional fields gracefully', (WidgetTester tester) async {
      final activityWithoutOptionals = EcoActivity(
        id: 'test-id',
        userId: 'user-1',
        type: 'Recycling',
        amount: 10.5,
        date: DateTime(2023, 12, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EcoActivityCard(activity: activityWithoutOptionals),
          ),
        ),
      );

      // Verify required fields are still displayed
      expect(find.text('RECYCLING'), findsOneWidget);
      expect(find.text('10.50 units'), findsOneWidget);
      
      // Verify optional fields are not displayed
      expect(find.byType(Chip), findsNothing);
      expect(find.text('Test description'), findsNothing);
    });

    testWidgets('calls onTap callback when tapped', (WidgetTester tester) async {
      bool wasTapped = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EcoActivityCard(
              activity: testActivity,
              onTap: () => wasTapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Card));
      expect(wasTapped, true);
    });

    testWidgets('applies correct theme styles', (WidgetTester tester) async {
      final ThemeData theme = ThemeData.light();
      
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: EcoActivityCard(activity: testActivity),
          ),
        ),
      );

      final titleFinder = find.text('RECYCLING');
      final titleWidget = tester.widget<Text>(titleFinder);
      expect(titleWidget.style?.fontWeight, FontWeight.bold);

      final chipFinder = find.byType(Chip);
      final chip = tester.widget<Chip>(chipFinder);
      expect(chip.backgroundColor, theme.colorScheme.primaryContainer);
    });
  });
}