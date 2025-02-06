import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:eco_tracker/src/core/services/firebase_auth_service.dart';

// Mock classes
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockGoogleSignIn extends Mock implements GoogleSignIn {}
class MockUserCredential extends Mock implements UserCredential {}
class MockUser extends Mock implements User {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}
class MockGoogleSignInAuthentication extends Mock implements GoogleSignInAuthentication {}

void main() {
  late FirebaseAuthService authService;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockUserCredential mockUserCredential;
  late MockUser mockUser;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    mockUserCredential = MockUserCredential();
    mockUser = MockUser();

    // Register fallback values
    registerFallbackValue(
      GoogleAuthProvider.credential(
        accessToken: 'test-token',
        idToken: 'test-id-token',
      ),
    );

    authService = FirebaseAuthService();
  });

  group('FirebaseAuthService', () {
    test('currentUser returns current user', () {
      when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
      expect(authService.currentUser, mockUser);
    });

    group('signInWithEmailAndPassword', () {
      test('successful sign in returns UserCredential', () async {
        when(() => mockFirebaseAuth.signInWithEmailAndPassword(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async => mockUserCredential);

        final result = await authService.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result, equals(mockUserCredential));
        verify(() => mockFirebaseAuth.signInWithEmailAndPassword(
              email: 'test@example.com',
              password: 'password123',
            )).called(1);
      });

      test('throws exception on auth error', () async {
        when(() => mockFirebaseAuth.signInWithEmailAndPassword(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenThrow(
          FirebaseAuthException(code: 'user-not-found'),
        );

        expect(
          () => authService.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password123',
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('signInWithGoogle', () {
      late MockGoogleSignInAccount mockGoogleSignInAccount;
      late MockGoogleSignInAuthentication mockGoogleSignInAuthentication;

      setUp(() {
        mockGoogleSignInAccount = MockGoogleSignInAccount();
        mockGoogleSignInAuthentication = MockGoogleSignInAuthentication();
      });

      test('successful Google sign in returns UserCredential', () async {
        when(() => mockGoogleSignIn.signIn())
            .thenAnswer((_) async => mockGoogleSignInAccount);
        when(() => mockGoogleSignInAccount.authentication)
            .thenAnswer((_) async => mockGoogleSignInAuthentication);
        when(() => mockGoogleSignInAuthentication.accessToken)
            .thenReturn('test-access-token');
        when(() => mockGoogleSignInAuthentication.idToken)
            .thenReturn('test-id-token');
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) async => mockUserCredential);

        final result = await authService.signInWithGoogle();

        expect(result, equals(mockUserCredential));
        verify(() => mockGoogleSignIn.signIn()).called(1);
        verify(() => mockFirebaseAuth.signInWithCredential(any())).called(1);
      });

      test('throws exception when Google sign in is aborted', () async {
        when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => null);

        expect(
          () => authService.signInWithGoogle(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('signOut', () {
      test('signs out from Firebase and Google', () async {
        when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});
        when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async => null);

        await authService.signOut();

        verify(() => mockFirebaseAuth.signOut()).called(1);
        verify(() => mockGoogleSignIn.signOut()).called(1);
      });

      test('throws exception on sign out error', () async {
        when(() => mockFirebaseAuth.signOut())
            .thenThrow(FirebaseAuthException(code: 'sign-out-failed'));

        expect(
          () => authService.signOut(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('sendPasswordResetEmail', () {
      test('sends password reset email successfully', () async {
        when(() => mockFirebaseAuth.sendPasswordResetEmail(
              email: any(named: 'email'),
            )).thenAnswer((_) async {});

        await authService.sendPasswordResetEmail('test@example.com');

        verify(() => mockFirebaseAuth.sendPasswordResetEmail(
              email: 'test@example.com',
            )).called(1);
      });

      test('throws exception on password reset error', () async {
        when(() => mockFirebaseAuth.sendPasswordResetEmail(
              email: any(named: 'email'),
            )).thenThrow(FirebaseAuthException(code: 'invalid-email'));

        expect(
          () => authService.sendPasswordResetEmail('test@example.com'),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}