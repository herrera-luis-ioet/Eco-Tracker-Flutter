import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:eco_tracker/src/core/bloc/app_bloc.dart';
import 'package:eco_tracker/src/features/activity/presentation/pages/activity_tracking_page.dart';
import 'package:eco_tracker/src/shared/widgets/activity_input_form.dart';

class MockAppBloc extends Mock implements AppBloc {}
class MockNavigatorObserver extends Mock implements NavigatorObserver {}

void main() {
  late MockAppBloc mockAppBloc;
  late MockNavigatorObserver mockNavigatorObserver;

  setUp(() {
    mockAppBloc = MockAppBloc();
    mockNavigatorObserver = MockNavigatorObserver();
    when(() => mockAppBloc.state).thenReturn(AppReady(
      recentActivities: [],
      totalActivities: 0,
      monthlyActivities: 0,
      impactScore: 0,
      userProfile: null,
    ));
  });

  Widget createActivityTrackingScreen() {
    return MaterialApp(
      home: BlocProvider<AppBloc>.value(
        value: mockAppBloc,
        child: const ActivityTrackingPage(),
      ),
      navigatorObservers: [mockNavigatorObserver],
    );
  }

  group('ActivityTrackingPage Widget Tests', () {
    testWidgets('displays correct title and form', (WidgetTester tester) async {
      await tester.pumpWidget(createActivityTrackingScreen());

      expect(find.text('Track Activity'), findsOneWidget);
      expect(find.text('Log Your Eco Activity'), findsOneWidget);
      expect(
        find.text('Track your environmental impact by logging your activities'),
        findsOneWidget,
      );
      expect(find.byType(ActivityInputForm), findsOneWidget);
    });

    testWidgets('submits activity when form is filled',
        (WidgetTester tester) async {
      await tester.pumpWidget(createActivityTrackingScreen());

      // Fill form fields
      await tester.enterText(
        find.byKey(const Key('activity_type_field')),
        'Recycling',
      );
      await tester.enterText(
        find.byKey(const Key('activity_amount_field')),
        '2.5',
      );
      await tester.enterText(
        find.byKey(const Key('activity_description_field')),
        'Recycled paper',
      );

      // Submit form
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      verify(
        () => mockAppBloc.add(
          LogActivity(
            type: 'Recycling',
            amount: 2.5,
            description: 'Recycled paper',
          ),
        ),
      ).called(1);
    });

    testWidgets('shows success message and navigates back on successful submission',
        (WidgetTester tester) async {
      await tester.pumpWidget(createActivityTrackingScreen());

      // Simulate successful submission
      when(() => mockAppBloc.state).thenReturn(ActivitySubmitted());
      await tester.pump();

      expect(find.text('Activity logged successfully'), findsOneWidget);
      verify(() => mockNavigatorObserver.didPop(any(), any())).called(1);
    });

    testWidgets('shows error message when submission fails',
        (WidgetTester tester) async {
      await tester.pumpWidget(createActivityTrackingScreen());

      // Simulate error state
      const errorMessage = 'Failed to log activity';
      when(() => mockAppBloc.state).thenReturn(AppError(errorMessage));
      await tester.pump();

      expect(find.text('Error: $errorMessage'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('validates required fields', (WidgetTester tester) async {
      await tester.pumpWidget(createActivityTrackingScreen());

      // Try to submit without filling required fields
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verify validation messages
      expect(find.text('Activity type is required'), findsOneWidget);
      expect(find.text('Amount is required'), findsOneWidget);

      // Verify that no submission was made
      verifyNever(() => mockAppBloc.add(any()));
    });
  });
}