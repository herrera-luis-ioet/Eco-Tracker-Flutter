import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:eco_tracker/src/core/bloc/app_bloc.dart';
import 'package:eco_tracker/src/core/models/eco_activity.dart';
import 'package:eco_tracker/src/features/home/presentation/pages/home_page.dart';

class MockAppBloc extends Mock implements AppBloc {}

void main() {
  late MockAppBloc mockAppBloc;

  setUp(() {
    mockAppBloc = MockAppBloc();
  });

  Widget createHomeScreen() {
    return MaterialApp(
      home: BlocProvider<AppBloc>.value(
        value: mockAppBloc,
        child: const HomePage(),
      ),
    );
  }

  group('HomePage Widget Tests', () {
    testWidgets('displays loading indicator when state is AppLoading',
        (WidgetTester tester) async {
      when(() => mockAppBloc.state).thenReturn(AppLoading());

      await tester.pumpWidget(createHomeScreen());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays error message when state is AppError',
        (WidgetTester tester) async {
      const errorMessage = 'Test error message';
      when(() => mockAppBloc.state).thenReturn(AppError(errorMessage));

      await tester.pumpWidget(createHomeScreen());

      expect(find.text('Error: $errorMessage'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('displays empty state when no activities',
        (WidgetTester tester) async {
      when(() => mockAppBloc.state).thenReturn(
        AppReady(
          recentActivities: [],
          totalActivities: 0,
          monthlyActivities: 0,
          impactScore: 0,
          userProfile: null,
        ),
      );

      await tester.pumpWidget(createHomeScreen());

      expect(find.text('No activities yet'), findsOneWidget);
      expect(
          find.text('Start tracking your eco-friendly activities'), findsOneWidget);
    });

    testWidgets('displays list of activities when available',
        (WidgetTester tester) async {
      final activities = [
        EcoActivity(
          id: '1',
          type: 'Recycling',
          amount: 2.5,
          timestamp: DateTime.now(),
          userId: 'user1',
        ),
        EcoActivity(
          id: '2',
          type: 'Energy Saving',
          amount: 1.0,
          timestamp: DateTime.now(),
          userId: 'user1',
        ),
      ];

      when(() => mockAppBloc.state).thenReturn(
        AppReady(
          recentActivities: activities,
          totalActivities: activities.length,
          monthlyActivities: activities.length,
          impactScore: 3.5,
          userProfile: null,
        ),
      );

      await tester.pumpWidget(createHomeScreen());

      expect(find.text('Recycling'), findsOneWidget);
      expect(find.text('Energy Saving'), findsOneWidget);
      expect(find.byType(EcoActivityCard), findsNWidgets(2));
    });

    testWidgets('navigates to profile page when profile icon is tapped',
        (WidgetTester tester) async {
      when(() => mockAppBloc.state).thenReturn(
        AppReady(
          recentActivities: [],
          totalActivities: 0,
          monthlyActivities: 0,
          impactScore: 0,
          userProfile: null,
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: BlocProvider<AppBloc>.value(
          value: mockAppBloc,
          child: const HomePage(),
        ),
        routes: {
          '/profile': (context) => const Scaffold(body: Text('Profile Page')),
        },
      ));

      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      expect(find.text('Profile Page'), findsOneWidget);
    });

    testWidgets('navigates to new activity page when FAB is tapped',
        (WidgetTester tester) async {
      when(() => mockAppBloc.state).thenReturn(
        AppReady(
          recentActivities: [],
          totalActivities: 0,
          monthlyActivities: 0,
          impactScore: 0,
          userProfile: null,
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: BlocProvider<AppBloc>.value(
          value: mockAppBloc,
          child: const HomePage(),
        ),
        routes: {
          '/activity/new': (context) =>
              const Scaffold(body: Text('New Activity Page')),
        },
      ));

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('New Activity Page'), findsOneWidget);
    });

    testWidgets('triggers refresh when pull-to-refresh is performed',
        (WidgetTester tester) async {
      when(() => mockAppBloc.state).thenReturn(
        AppReady(
          recentActivities: [],
          totalActivities: 0,
          monthlyActivities: 0,
          impactScore: 0,
          userProfile: null,
        ),
      );

      await tester.pumpWidget(createHomeScreen());

      await tester.drag(find.byType(RefreshIndicator), const Offset(0, 300));
      await tester.pumpAndSettle();

      verify(() => mockAppBloc.add(RefreshData())).called(1);
    });
  });
}