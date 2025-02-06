import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:eco_tracker/src/core/bloc/app_bloc.dart';
import 'package:eco_tracker/src/core/models/user_profile.dart';
import 'package:eco_tracker/src/features/profile/presentation/pages/profile_page.dart';

class MockAppBloc extends Mock implements AppBloc {}

void main() {
  late MockAppBloc mockAppBloc;
  late UserProfile testProfile;

  setUp(() {
    mockAppBloc = MockAppBloc();
    testProfile = UserProfile(
      id: 'test_id',
      email: 'test@example.com',
      displayName: 'Test User',
      photoUrl: null,
      preferences: {
        'darkMode': true,
        'notifications': false,
      },
    );
  });

  Widget createProfileScreen() {
    return MaterialApp(
      home: BlocProvider<AppBloc>.value(
        value: mockAppBloc,
        child: const ProfilePage(),
      ),
    );
  }

  group('ProfilePage Widget Tests', () {
    testWidgets('displays loading indicator when state is AppLoading',
        (WidgetTester tester) async {
      when(() => mockAppBloc.state).thenReturn(AppLoading());

      await tester.pumpWidget(createProfileScreen());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays error message when state is AppError',
        (WidgetTester tester) async {
      const errorMessage = 'Failed to load profile';
      when(() => mockAppBloc.state).thenReturn(AppError(errorMessage));

      await tester.pumpWidget(createProfileScreen());

      expect(find.text('Error: $errorMessage'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('displays user profile information correctly',
        (WidgetTester tester) async {
      when(() => mockAppBloc.state).thenReturn(
        AppReady(
          recentActivities: [],
          totalActivities: 10,
          monthlyActivities: 5,
          impactScore: 8.5,
          userProfile: testProfile,
        ),
      );

      await tester.pumpWidget(createProfileScreen());

      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('Profile Information'), findsOneWidget);
    });

    testWidgets('displays avatar with initials when no photo URL',
        (WidgetTester tester) async {
      when(() => mockAppBloc.state).thenReturn(
        AppReady(
          recentActivities: [],
          totalActivities: 10,
          monthlyActivities: 5,
          impactScore: 8.5,
          userProfile: testProfile,
        ),
      );

      await tester.pumpWidget(createProfileScreen());

      final avatar = find.byType(CircleAvatar);
      expect(avatar, findsOneWidget);
      expect(find.text('T'), findsOneWidget); // First letter of Test User
    });

    testWidgets('handles preference toggles correctly',
        (WidgetTester tester) async {
      when(() => mockAppBloc.state).thenReturn(
        AppReady(
          recentActivities: [],
          totalActivities: 10,
          monthlyActivities: 5,
          impactScore: 8.5,
          userProfile: testProfile,
        ),
      );

      await tester.pumpWidget(createProfileScreen());

      // Test dark mode toggle
      await tester.tap(find.byType(Switch).first);
      await tester.pump();

      verify(
        () => mockAppBloc.add(
          UpdatePreference(key: 'darkMode', value: false),
        ),
      ).called(1);

      // Test notifications toggle
      await tester.tap(find.byType(Switch).last);
      await tester.pump();

      verify(
        () => mockAppBloc.add(
          UpdatePreference(key: 'notifications', value: true),
        ),
      ).called(1);
    });

    testWidgets('displays statistics correctly', (WidgetTester tester) async {
      when(() => mockAppBloc.state).thenReturn(
        AppReady(
          recentActivities: [],
          totalActivities: 10,
          monthlyActivities: 5,
          impactScore: 8.5,
          userProfile: testProfile,
        ),
      );

      await tester.pumpWidget(createProfileScreen());

      expect(find.text('Activity Statistics'), findsOneWidget);
      expect(find.text('10'), findsOneWidget); // Total Activities
      expect(find.text('5'), findsOneWidget); // Monthly Activities
      expect(find.text('8.5'), findsOneWidget); // Impact Score
    });

    testWidgets('handles logout request', (WidgetTester tester) async {
      when(() => mockAppBloc.state).thenReturn(
        AppReady(
          recentActivities: [],
          totalActivities: 10,
          monthlyActivities: 5,
          impactScore: 8.5,
          userProfile: testProfile,
        ),
      );

      await tester.pumpWidget(createProfileScreen());

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pump();

      verify(() => mockAppBloc.add(LogoutRequested())).called(1);
    });
  });
}