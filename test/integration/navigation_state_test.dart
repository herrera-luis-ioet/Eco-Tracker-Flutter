import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:eco_tracker/main.dart' as app;
import 'package:eco_tracker/src/config/routes.dart';
import 'package:eco_tracker/src/core/bloc/app_bloc.dart';
import 'package:eco_tracker/src/core/bloc/auth_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Navigation and State Management Integration Tests', () {
    testWidgets('Authentication flow and navigation', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Initially should be on login page
      expect(find.text('Login'), findsOneWidget);

      // Simulate login
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;
      final loginButton = find.byType(ElevatedButton);

      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Should be redirected to home page
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);

      // Verify navigation to different pages
      final bottomNavItems = find.byType(BottomNavigationBarItem);
      
      // Navigate to Emissions page
      await tester.tap(bottomNavItems.at(1));
      await tester.pumpAndSettle();
      expect(find.text('Emissions'), findsOneWidget);

      // Navigate to Challenges page
      await tester.tap(bottomNavItems.at(2));
      await tester.pumpAndSettle();
      expect(find.text('Challenges'), findsOneWidget);

      // Navigate to Profile page
      await tester.tap(bottomNavItems.at(3));
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('State persistence during navigation', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Login first
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;
      final loginButton = find.byType(ElevatedButton);

      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Navigate to Profile and make changes
      final bottomNavItems = find.byType(BottomNavigationBarItem);
      await tester.tap(bottomNavItems.at(3));
      await tester.pumpAndSettle();

      // Update theme mode
      final themeSwitch = find.byType(Switch);
      await tester.tap(themeSwitch);
      await tester.pumpAndSettle();

      // Navigate away and back
      await tester.tap(bottomNavItems.at(0)); // Go to Home
      await tester.pumpAndSettle();
      await tester.tap(bottomNavItems.at(3)); // Back to Profile
      await tester.pumpAndSettle();

      // Verify theme state persisted
      final appBloc = tester.state<AppBloc>(find.byType(BlocProvider<AppBloc>));
      expect((appBloc.state as AppReady).isDarkMode, isTrue);
    });

    testWidgets('Error state handling', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Attempt login with invalid credentials
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;
      final loginButton = find.byType(ElevatedButton);

      await tester.enterText(emailField, 'invalid@email.com');
      await tester.enterText(passwordField, 'wrongpassword');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Verify error state is handled
      expect(find.text('Invalid email or password'), findsOneWidget);
    });

    testWidgets('Authentication state changes', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Login
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;
      final loginButton = find.byType(ElevatedButton);

      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Navigate to Profile
      final bottomNavItems = find.byType(BottomNavigationBarItem);
      await tester.tap(bottomNavItems.at(3));
      await tester.pumpAndSettle();

      // Sign out
      final signOutButton = find.byType(TextButton).last;
      await tester.tap(signOutButton);
      await tester.pumpAndSettle();

      // Verify redirect to login page
      expect(find.text('Login'), findsOneWidget);
    });
  });
}