import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_tracker/src/core/services/firebase_service.dart';
import 'package:eco_tracker/src/core/exceptions/firebase_exceptions.dart';
import 'package:eco_tracker/src/core/utils/network_checker.dart';

// Mock classes
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference {}
class MockDocumentReference extends Mock implements DocumentReference {}
class MockQuerySnapshot extends Mock implements QuerySnapshot {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot {}
class MockUser extends Mock implements User {}
class MockNetworkChecker extends Mock implements NetworkChecker {}

void main() {
  late FirebaseService firebaseService;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockNetworkChecker mockNetworkChecker;
  late MockUser mockUser;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockNetworkChecker = MockNetworkChecker();
    mockUser = MockUser();

    // Register fallback values
    registerFallbackValue(MockCollectionReference());
    registerFallbackValue(MockDocumentReference());

    // Set up default mock behavior
    when(() => mockUser.uid).thenReturn('test-user-id');
    when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
    
    // Initialize service with mocks
    FirebaseService.instance = FirebaseService._internal();
    FirebaseService.instance._networkChecker = mockNetworkChecker;
  });

  group('FirebaseService Error Handling', () {
    group('Network Connectivity', () {
      test('should throw FirebaseNetworkException when no network connection', () async {
        // Arrange
        when(() => mockNetworkChecker.hasConnection()).thenAnswer((_) async => false);

        // Act & Assert
        expect(
          () => FirebaseService.instance.initialize(),
          throwsA(isA<FirebaseNetworkException>()),
        );
      });

      test('should proceed with operation when network is available', () async {
        // Arrange
        when(() => mockNetworkChecker.hasConnection()).thenAnswer((_) async => true);

        // Act & Assert
        expect(
          () => FirebaseService.instance.initialize(),
          returnsNormally,
        );
      });
    });

    group('Retry Mechanism', () {
      test('should retry failed operations up to maxRetries times', () async {
        // Arrange
        int attempts = 0;
        when(() => mockNetworkChecker.hasConnection()).thenAnswer((_) async => true);
        
        // Simulate operation that fails twice then succeeds
        when(() => mockFirestore.collection(any())).thenAnswer((_) {
          attempts++;
          if (attempts < 3) {
            throw FirebaseException(plugin: 'test', message: 'Test error');
          }
          return MockCollectionReference();
        });

        // Act
        await FirebaseService.instance.logEmissions(10.0, DateTime.now());

        // Assert
        verify(() => mockFirestore.collection(any())).called(3);
      });

      test('should throw FirebaseRetryException after maxRetries failures', () async {
        // Arrange
        when(() => mockNetworkChecker.hasConnection()).thenAnswer((_) async => true);
        when(() => mockFirestore.collection(any()))
            .thenThrow(FirebaseException(plugin: 'test', message: 'Test error'));

        // Act & Assert
        expect(
          () => FirebaseService.instance.logEmissions(10.0, DateTime.now()),
          throwsA(isA<FirebaseRetryException>()),
        );
      });
    });

    group('Timeout Handling', () {
      test('should throw FirebaseTimeoutException when operation times out', () async {
        // Arrange
        when(() => mockNetworkChecker.hasConnection()).thenAnswer((_) async => true);
        when(() => mockFirestore.collection(any())).thenAnswer(
          (_) => Future.delayed(
            const Duration(seconds: 31),
            () => MockCollectionReference(),
          ),
        );

        // Act & Assert
        expect(
          () => FirebaseService.instance.logEmissions(10.0, DateTime.now()),
          throwsA(isA<FirebaseTimeoutException>()),
        );
      });
    });

    group('Exponential Backoff', () {
      test('should implement exponential backoff between retries', () async {
        // Arrange
        final stopwatch = Stopwatch()..start();
        when(() => mockNetworkChecker.hasConnection()).thenAnswer((_) async => true);
        when(() => mockFirestore.collection(any()))
            .thenThrow(FirebaseException(plugin: 'test', message: 'Test error'));

        // Act
        try {
          await FirebaseService.instance.logEmissions(10.0, DateTime.now());
        } catch (_) {}
        stopwatch.stop();

        // Assert - Should take at least 6 seconds (2 + 4 seconds for backoff)
        expect(stopwatch.elapsed.inSeconds, greaterThanOrEqualTo(6));
      });
    });

    group('Authentication State', () {
      test('should throw FirebaseException when user is not logged in', () async {
        // Arrange
        when(() => mockFirebaseAuth.currentUser).thenReturn(null);
        when(() => mockNetworkChecker.hasConnection()).thenAnswer((_) async => true);

        // Act & Assert
        expect(
          () => FirebaseService.instance.logEmissions(10.0, DateTime.now()),
          throwsA(isA<FirebaseException>()),
        );
      });
    });
  });
}
