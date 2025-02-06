import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../lib/src/core/services/sync_service.dart';
import '../../../lib/src/core/services/firebase_service.dart';
import '../../../lib/src/core/services/local_storage_service.dart';
import '../../../lib/src/core/utils/network_checker.dart';
import '../../../lib/src/core/models/eco_activity.dart';

@GenerateMocks([
  FirebaseService,
  LocalStorageService,
  NetworkChecker,
  Connectivity,
])
void main() {
  late SyncService syncService;
  late MockFirebaseService mockFirebaseService;
  late MockLocalStorageService mockLocalStorageService;
  late MockNetworkChecker mockNetworkChecker;
  late MockConnectivity mockConnectivity;
  late StreamController<ConnectivityResult> connectivityStreamController;

  final testActivity = EcoActivity(
    id: 'test-id-1',
    userId: 'user-1',
    type: 'recycling',
    amount: 10.0,
    date: DateTime(2023, 1, 1),
    description: 'Test activity',
    category: 'home',
  );

  setUp(() {
    mockFirebaseService = MockFirebaseService();
    mockLocalStorageService = MockLocalStorageService();
    mockNetworkChecker = MockNetworkChecker();
    mockConnectivity = MockConnectivity();
    connectivityStreamController = StreamController<ConnectivityResult>();

    // Setup connectivity stream
    when(mockConnectivity.onConnectivityChanged)
        .thenAnswer((_) => connectivityStreamController.stream);

    // Setup default network checker response
    when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => true);

    // Setup default local storage responses
    when(mockLocalStorageService.initialize()).thenAnswer((_) async => {});
    when(mockLocalStorageService.saveActivity(any)).thenAnswer((_) async => true);
    when(mockLocalStorageService.updateActivity(any)).thenAnswer((_) async => true);
    when(mockLocalStorageService.deleteActivity(any)).thenAnswer((_) async => true);
    when(mockLocalStorageService.getActivity(any))
        .thenAnswer((_) async => testActivity);

    // Setup default Firebase responses
    when(mockFirebaseService.logEmissions(any, any))
        .thenAnswer((_) async => {});
    when(mockFirebaseService.deleteEmission(any))
        .thenAnswer((_) async => {});

    // Initialize SyncService with mocks
    syncService = SyncService.instance;
    syncService._firebaseService = mockFirebaseService;
    syncService._localStorageService = mockLocalStorageService;
    syncService._networkChecker = mockNetworkChecker;
  });

  tearDown(() {
    syncService.dispose();
    connectivityStreamController.close();
  });

  group('SyncService - Initialization', () {
    test('initialize should setup local storage and start monitoring', () async {
      await syncService.initialize();

      verify(mockLocalStorageService.initialize()).called(1);
    });
  });

  group('SyncService - Activity Operations', () {
    setUp(() async {
      await syncService.initialize();
    });

    test('addActivity should save locally and queue for sync', () async {
      final result = await syncService.addActivity(testActivity);

      expect(result, true);
      verify(mockLocalStorageService.saveActivity(testActivity)).called(1);
      verify(mockNetworkChecker.hasConnection()).called(1);
    });

    test('updateActivity should update locally and queue for sync', () async {
      final result = await syncService.updateActivity(testActivity);

      expect(result, true);
      verify(mockLocalStorageService.updateActivity(testActivity)).called(1);
      verify(mockNetworkChecker.hasConnection()).called(1);
    });

    test('deleteActivity should remove locally and queue for sync', () async {
      final result = await syncService.deleteActivity(testActivity.id);

      expect(result, true);
      verify(mockLocalStorageService.deleteActivity(testActivity.id)).called(1);
      verify(mockNetworkChecker.hasConnection()).called(1);
    });
  });

  group('SyncService - Sync Operations', () {
    setUp(() async {
      await syncService.initialize();
    });

    test('should sync when network becomes available', () async {
      // Add an activity to queue sync operation
      await syncService.addActivity(testActivity);

      // Simulate network becoming available
      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 100));

      verify(mockFirebaseService.logEmissions(
        testActivity.emissionAmount,
        testActivity.timestamp,
      )).called(1);
    });

    test('should not sync when offline', () async {
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => false);

      await syncService.addActivity(testActivity);
      await Future.delayed(const Duration(milliseconds: 100));

      verifyNever(mockFirebaseService.logEmissions(any, any));
    });

    test('should retry failed sync operations', () async {
      // Setup Firebase to fail once then succeed
      var attempts = 0;
      when(mockFirebaseService.logEmissions(any, any)).thenAnswer((_) async {
        if (attempts == 0) {
          attempts++;
          throw Exception('Sync failed');
        }
        return {};
      });

      await syncService.addActivity(testActivity);
      await Future.delayed(const Duration(milliseconds: 100));

      verify(mockFirebaseService.logEmissions(
        testActivity.emissionAmount,
        testActivity.timestamp,
      )).called(2);
    });
  });

  group('SyncService - Retry Mechanism', () {
    setUp(() async {
      await syncService.initialize();
    });

    test('should implement exponential backoff timing', () async {
      // Setup Firebase to fail multiple times
      var attempts = 0;
      var lastCallTime = DateTime.now();
      var delayTimes = <Duration>[];

      when(mockFirebaseService.logEmissions(any, any)).thenAnswer((_) async {
        if (attempts < 3) {
          var now = DateTime.now();
          if (attempts > 0) {
            delayTimes.add(now.difference(lastCallTime));
          }
          lastCallTime = now;
          attempts++;
          throw Exception('Sync failed');
        }
        return {};
      });

      await syncService.addActivity(testActivity);
      await Future.delayed(const Duration(seconds: 2)); // Wait for retries to complete

      // Verify exponential backoff timing
      expect(delayTimes.length, 2); // Two delays for three attempts
      expect(delayTimes[0].inSeconds, closeTo(30, 5)); // First retry around 30 seconds
      expect(delayTimes[1].inSeconds, closeTo(60, 5)); // Second retry around 60 seconds
    });

    test('should respect maximum retry attempts', () async {
      var attempts = 0;
      when(mockFirebaseService.logEmissions(any, any)).thenAnswer((_) async {
        attempts++;
        throw Exception('Sync failed');
      });

      await syncService.addActivity(testActivity);
      await Future.delayed(const Duration(seconds: 3)); // Wait for all retries

      expect(attempts, 3); // Initial attempt + 2 retries = 3 total attempts
      expect(syncService._pendingOperations.length, 1); // Operation should remain in queue
    });

    test('should reset retry counter after successful sync', () async {
      var firstOperationAttempts = 0;
      var secondOperationAttempts = 0;
      var firstOperationComplete = false;

      when(mockFirebaseService.logEmissions(any, any)).thenAnswer((_) async {
        if (!firstOperationComplete) {
          firstOperationAttempts++;
          if (firstOperationAttempts < 2) {
            throw Exception('First sync failed');
          }
          firstOperationComplete = true;
          return {};
        } else {
          secondOperationAttempts++;
          if (secondOperationAttempts < 2) {
            throw Exception('Second sync failed');
          }
          return {};
        }
      });

      // Add first activity
      await syncService.addActivity(testActivity);
      await Future.delayed(const Duration(seconds: 2));

      // Add second activity
      final activity2 = EcoActivity(
        id: 'test-id-2',
        userId: 'user-1',
        type: 'transport',
        amount: 15.0,
        date: DateTime(2023, 1, 2),
        description: 'Second activity',
        category: 'transport',
      );
      await syncService.addActivity(activity2);
      await Future.delayed(const Duration(seconds: 2));

      expect(firstOperationAttempts, 2); // First operation succeeded after 2 attempts
      expect(secondOperationAttempts, 2); // Second operation got fresh retry count
      expect(syncService._pendingOperations.isEmpty, true);
    });

    test('should abandon retry and propagate error after max retries', () async {
      var attempts = 0;
      var lastError;

      when(mockFirebaseService.logEmissions(any, any)).thenAnswer((_) async {
        attempts++;
        final error = Exception('Sync failed after $attempts attempts');
        lastError = error;
        throw error;
      });

      await syncService.addActivity(testActivity);
      await Future.delayed(const Duration(seconds: 3));

      expect(attempts, 3); // Should stop after max retries
      expect(syncService._pendingOperations.length, 1); // Operation should remain in queue
      expect(lastError.toString(), contains('Sync failed after 3 attempts'));
    });

    test('should handle concurrent retries for multiple operations', () async {
      final activities = List.generate(
        3,
        (i) => EcoActivity(
          id: 'test-id-${i + 1}',
          userId: 'user-1',
          type: 'recycling',
          amount: 10.0 * (i + 1),
          date: DateTime(2023, 1, i + 1),
          description: 'Activity ${i + 1}',
          category: 'home',
        ),
      );

      var operationAttempts = <String, int>{};
      when(mockFirebaseService.logEmissions(any, any)).thenAnswer((invocation) async {
        final amount = invocation.positionalArguments[0] as double;
        final activityIndex = (amount / 10.0).round() - 1;
        final activityId = 'test-id-${activityIndex + 1}';
        
        operationAttempts[activityId] = (operationAttempts[activityId] ?? 0) + 1;
        
        if (operationAttempts[activityId]! < 2) {
          throw Exception('Sync failed for activity $activityId');
        }
        return {};
      });

      // Add all activities
      for (var activity in activities) {
        await syncService.addActivity(activity);
      }
      await Future.delayed(const Duration(seconds: 3));

      // Verify each operation had independent retry attempts
      for (var activity in activities) {
        expect(operationAttempts[activity.id], 2,
            reason: 'Activity ${activity.id} should have 2 attempts');
      }
      expect(syncService._pendingOperations.isEmpty, true);
    });
  });

  group('SyncService - Error Handling', () {
    setUp(() async {
      await syncService.initialize();
    });

    test('should handle local storage failures gracefully', () async {
      when(mockLocalStorageService.saveActivity(any))
          .thenAnswer((_) async => false);

      final result = await syncService.addActivity(testActivity);

      expect(result, false);
      verifyNever(mockFirebaseService.logEmissions(any, any));
    });

    test('should handle sync failures gracefully', () async {
      when(mockFirebaseService.logEmissions(any, any))
          .thenThrow(Exception('Sync failed'));

      await syncService.addActivity(testActivity);
      await Future.delayed(const Duration(milliseconds: 100));

      // Should attempt to sync but handle the error
      verify(mockFirebaseService.logEmissions(
        testActivity.emissionAmount,
        testActivity.timestamp,
      )).called(3); // Will try 3 times due to _maxRetries
    });
  });

  group('SyncService - Network Transitions', () {
    setUp(() async {
      await syncService.initialize();
    });

    test('should queue operations when network is lost during sync', () async {
      // Setup initial state with network available
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => true);
      
      // Add multiple activities
      final activity2 = EcoActivity(
        id: 'test-id-2',
        userId: 'user-1',
        type: 'transport',
        amount: 15.0,
        date: DateTime(2023, 1, 2),
        description: 'Second activity',
        category: 'transport',
      );

      await syncService.addActivity(testActivity);
      await syncService.addActivity(activity2);

      // Simulate network loss during sync
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => false);
      connectivityStreamController.add(ConnectivityResult.none);
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify operations are queued
      expect(syncService._pendingOperations.length, 2);
      verifyNever(mockFirebaseService.logEmissions(any, any));
    });

    test('should resume sync when network is restored', () async {
      // Start with no network
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => false);
      await syncService.addActivity(testActivity);
      
      // Verify operation is queued but not synced
      expect(syncService._pendingOperations.length, 1);
      verifyNever(mockFirebaseService.logEmissions(any, any));

      // Restore network
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => true);
      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify sync occurred
      verify(mockFirebaseService.logEmissions(
        testActivity.emissionAmount,
        testActivity.timestamp,
      )).called(1);
      expect(syncService._pendingOperations.isEmpty, true);
    });

    test('should handle multiple network transitions during sync', () async {
      // Setup multiple activities
      final activities = List.generate(
        3,
        (i) => EcoActivity(
          id: 'test-id-${i + 1}',
          userId: 'user-1',
          type: 'recycling',
          amount: 10.0 * (i + 1),
          date: DateTime(2023, 1, i + 1),
          description: 'Activity ${i + 1}',
          category: 'home',
        ),
      );

      // Start with network available
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => true);
      
      // Add activities
      for (var activity in activities) {
        await syncService.addActivity(activity);
      }

      // Simulate network transitions during sync
      when(mockNetworkChecker.hasConnection())
          .thenAnswer((_) async => false); // Network lost
      connectivityStreamController.add(ConnectivityResult.none);
      await Future.delayed(const Duration(milliseconds: 50));

      when(mockNetworkChecker.hasConnection())
          .thenAnswer((_) async => true); // Network restored
      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 50));

      when(mockNetworkChecker.hasConnection())
          .thenAnswer((_) async => false); // Network lost again
      connectivityStreamController.add(ConnectivityResult.none);
      await Future.delayed(const Duration(milliseconds: 50));

      // Final network restoration
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => true);
      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify all activities eventually synced
      for (var activity in activities) {
        verify(mockFirebaseService.logEmissions(
          activity.emissionAmount,
          activity.timestamp,
        )).called(1);
      }
      expect(syncService._pendingOperations.isEmpty, true);
    });

    test('should handle error during sync after network restoration', () async {
      // Start with no network
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => false);
      await syncService.addActivity(testActivity);

      // Setup Firebase to fail on first attempt after network restoration
      var syncAttempts = 0;
      when(mockFirebaseService.logEmissions(any, any)).thenAnswer((_) async {
        syncAttempts++;
        if (syncAttempts == 1) {
          throw Exception('Sync failed after network restoration');
        }
        return {};
      });

      // Restore network
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => true);
      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify retry behavior
      verify(mockFirebaseService.logEmissions(
        testActivity.emissionAmount,
        testActivity.timestamp,
      )).called(2); // One failed attempt + one successful retry
      expect(syncService._pendingOperations.isEmpty, true);
    });

    test('should maintain operation order during network transitions', () async {
      // Setup activities with different timestamps
      final activities = List.generate(
        3,
        (i) => EcoActivity(
          id: 'test-id-${i + 1}',
          userId: 'user-1',
          type: 'recycling',
          amount: 10.0 * (i + 1),
          date: DateTime(2023, 1, i + 1),
          description: 'Activity ${i + 1}',
          category: 'home',
        ),
      );

      // Start with no network
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => false);
      
      // Queue activities
      for (var activity in activities) {
        await syncService.addActivity(activity);
      }

      // Verify queue order before sync
      expect(syncService._pendingOperations.length, 3);
      expect(syncService._pendingOperations[0].activity.id, 'test-id-1');
      expect(syncService._pendingOperations[1].activity.id, 'test-id-2');
      expect(syncService._pendingOperations[2].activity.id, 'test-id-3');

      // Restore network
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => true);
      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify sync order
      verifyInOrder([
        mockFirebaseService.logEmissions(activities[0].emissionAmount, activities[0].timestamp),
        mockFirebaseService.logEmissions(activities[1].emissionAmount, activities[1].timestamp),
        mockFirebaseService.logEmissions(activities[2].emissionAmount, activities[2].timestamp),
      ]);
    });
  });

  group('SyncService - Conflict Resolution', () {
    setUp(() async {
      await syncService.initialize();
    });

    test('should resolve conflicts based on timestamp for concurrent updates', () async {
      final originalActivity = EcoActivity(
        id: 'conflict-test-1',
        userId: 'user-1',
        type: 'recycling',
        amount: 10.0,
        date: DateTime(2023, 1, 1),
        description: 'Original activity',
        category: 'home',
        timestamp: DateTime(2023, 1, 1, 10, 0), // 10:00 AM
      );

      final localUpdate = EcoActivity(
        id: 'conflict-test-1',
        userId: 'user-1',
        type: 'recycling',
        amount: 15.0,
        date: DateTime(2023, 1, 1),
        description: 'Local update',
        category: 'home',
        timestamp: DateTime(2023, 1, 1, 10, 30), // 10:30 AM
      );

      final remoteUpdate = EcoActivity(
        id: 'conflict-test-1',
        userId: 'user-1',
        type: 'recycling',
        amount: 20.0,
        date: DateTime(2023, 1, 1),
        description: 'Remote update',
        category: 'home',
        timestamp: DateTime(2023, 1, 1, 11, 0), // 11:00 AM
      );

      // Setup local storage to return the local update
      when(mockLocalStorageService.getActivity('conflict-test-1'))
          .thenAnswer((_) async => localUpdate);

      // Setup Firebase to simulate a conflict by throwing a custom exception
      var syncAttempt = 0;
      when(mockFirebaseService.logEmissions(any, any))
          .thenAnswer((_) async {
        syncAttempt++;
        if (syncAttempt == 1) {
          // Simulate remote conflict on first attempt
          throw Exception('Conflict: Remote version is newer');
        }
        return {};
      });

      // Attempt to sync local update
      await syncService.updateActivity(localUpdate);
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify conflict resolution behavior
      verify(mockLocalStorageService.getActivity('conflict-test-1')).called(1);
      verify(mockFirebaseService.logEmissions(
        remoteUpdate.emissionAmount,
        remoteUpdate.timestamp,
      )).called(1);
    });

    test('should handle offline conflict resolution', () async {
      final offlineActivity = EcoActivity(
        id: 'offline-test-1',
        userId: 'user-1',
        type: 'recycling',
        amount: 10.0,
        date: DateTime(2023, 1, 1),
        description: 'Offline activity',
        category: 'home',
        timestamp: DateTime(2023, 1, 1, 10, 0),
      );

      // Start with no network connection
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => false);

      // Make offline changes
      await syncService.addActivity(offlineActivity);
      
      // Verify activity is queued
      expect(syncService._pendingOperations.length, 1);
      expect(syncService._pendingOperations.first.activity.id, 'offline-test-1');

      // Simulate network restoration with conflict
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => true);
      var syncAttempt = 0;
      when(mockFirebaseService.logEmissions(any, any))
          .thenAnswer((_) async {
        syncAttempt++;
        if (syncAttempt == 1) {
          // Simulate remote conflict
          throw Exception('Conflict detected');
        }
        return {};
      });

      // Trigger sync
      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify conflict handling
      verify(mockFirebaseService.logEmissions(
        offlineActivity.emissionAmount,
        offlineActivity.timestamp,
      )).called(2); // One failed attempt + one successful retry
    });

    test('should handle multiple concurrent conflicts', () async {
      final activities = List.generate(
        3,
        (i) => EcoActivity(
          id: 'concurrent-test-${i + 1}',
          userId: 'user-1',
          type: 'recycling',
          amount: 10.0 * (i + 1),
          date: DateTime(2023, 1, i + 1),
          description: 'Activity ${i + 1}',
          category: 'home',
          timestamp: DateTime(2023, 1, 1, 10, i),
        ),
      );

      // Setup conflict simulation for each activity
      final conflictResponses = <String, int>{};
      when(mockFirebaseService.logEmissions(any, any))
          .thenAnswer((invocation) async {
        final amount = invocation.positionalArguments[0] as double;
        final activityIndex = (amount / 10.0).round() - 1;
        final activityId = 'concurrent-test-${activityIndex + 1}';
        
        conflictResponses[activityId] = (conflictResponses[activityId] ?? 0) + 1;
        
        if (conflictResponses[activityId]! == 1) {
          throw Exception('Conflict for activity $activityId');
        }
        return {};
      });

      // Add all activities
      for (var activity in activities) {
        await syncService.addActivity(activity);
      }

      // Trigger sync
      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify each activity was handled
      for (var activity in activities) {
        verify(mockFirebaseService.logEmissions(
          activity.emissionAmount,
          activity.timestamp,
        )).called(2); // One conflict + one success
      }
      expect(syncService._pendingOperations.isEmpty, true);
    });

    test('should handle conflict with data consistency', () async {
      final originalActivity = EcoActivity(
        id: 'consistency-test-1',
        userId: 'user-1',
        type: 'recycling',
        amount: 10.0,
        date: DateTime(2023, 1, 1),
        description: 'Original activity',
        category: 'home',
        timestamp: DateTime(2023, 1, 1, 10, 0),
      );

      // Setup mock to simulate data consistency check
      var syncAttempt = 0;
      when(mockFirebaseService.logEmissions(any, any))
          .thenAnswer((_) async {
        syncAttempt++;
        if (syncAttempt == 1) {
          // Simulate consistency check failure
          throw Exception('Data consistency error');
        }
        return {};
      });

      await syncService.addActivity(originalActivity);
      
      // Trigger sync
      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify consistency handling
      verify(mockLocalStorageService.getActivity(originalActivity.id)).called(1);
      verify(mockFirebaseService.logEmissions(
        originalActivity.emissionAmount,
        originalActivity.timestamp,
      )).called(2); // One failed attempt + one successful retry
    });

    test('should handle error propagation during conflict resolution', () async {
      final activity = EcoActivity(
        id: 'error-test-1',
        userId: 'user-1',
        type: 'recycling',
        amount: 10.0,
        date: DateTime(2023, 1, 1),
        description: 'Test activity',
        category: 'home',
        timestamp: DateTime(2023, 1, 1, 10, 0),
      );

      // Setup mock to simulate error during conflict resolution
      when(mockFirebaseService.logEmissions(any, any))
          .thenThrow(Exception('Unrecoverable error during conflict resolution'));

      await syncService.addActivity(activity);
      
      // Trigger sync
      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify error handling
      verify(mockFirebaseService.logEmissions(
        activity.emissionAmount,
        activity.timestamp,
      )).called(3); // Will try 3 times due to _maxRetries
      expect(syncService._pendingOperations.length, 1); // Operation should remain in queue
    });
  });

  group('SyncService - Resource Cleanup', () {
    setUp(() async {
      await syncService.initialize();
    });

    test('should cancel sync timer on dispose', () async {
      // Add an activity to ensure timer is running
      await syncService.addActivity(testActivity);
      
      // Dispose service
      syncService.dispose();
      
      // Verify timer is cancelled by attempting sync
      await Future.delayed(const Duration(seconds: 16)); // Wait longer than sync interval
      verifyNever(mockFirebaseService.logEmissions(any, any));
    });

    test('should cancel connectivity subscription on dispose', () async {
      syncService.dispose();
      
      // Simulate connectivity change after disposal
      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verify no sync attempts after disposal
      verifyNever(mockFirebaseService.logEmissions(any, any));
    });

    test('should handle pending operations during disposal', () async {
      // Setup offline state
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => false);
      
      // Add activities to create pending operations
      await syncService.addActivity(testActivity);
      final activity2 = EcoActivity(
        id: 'test-id-2',
        userId: 'user-1',
        type: 'transport',
        amount: 15.0,
        date: DateTime(2023, 1, 2),
        description: 'Second activity',
        category: 'transport',
      );
      await syncService.addActivity(activity2);
      
      // Verify operations are queued
      expect(syncService._pendingOperations.length, 2);
      
      // Dispose service
      syncService.dispose();
      
      // Simulate network restoration after disposal
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => true);
      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verify no sync attempts after disposal
      verifyNever(mockFirebaseService.logEmissions(any, any));
    });

    test('should cleanup resources when disposed during sync operation', () async {
      // Setup sync to take some time
      final completer = Completer<void>();
      when(mockFirebaseService.logEmissions(any, any)).thenAnswer((_) => completer.future);
      
      // Start sync operation
      await syncService.addActivity(testActivity);
      connectivityStreamController.add(ConnectivityResult.wifi);
      
      // Dispose while sync is in progress
      syncService.dispose();
      
      // Complete the sync operation
      completer.complete();
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verify no further sync attempts
      verify(mockFirebaseService.logEmissions(any, any)).called(1);
      verifyNoMoreInteractions(mockFirebaseService);
    });

    test('should handle multiple resource cleanup scenarios', () async {
      // Setup multiple resources
      await syncService.addActivity(testActivity);
      final subscription = connectivityStreamController.stream.listen((_) {});
      
      // Verify resources are active
      expect(syncService._syncTimer, isNotNull);
      expect(syncService._connectivitySubscription, isNotNull);
      expect(syncService._pendingOperations.isNotEmpty, true);
      
      // Dispose service
      syncService.dispose();
      
      // Verify all resources are cleaned up
      expect(syncService._syncTimer, isNull);
      expect(syncService._connectivitySubscription, isNull);
      
      // Verify no memory leaks by attempting operations
      await syncService.addActivity(testActivity);
      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 100));
      
      verifyNever(mockFirebaseService.logEmissions(any, any));
      
      // Cleanup test subscription
      await subscription.cancel();
    });

    test('should prevent resource leaks during rapid initialize/dispose cycles', () async {
      // Perform rapid initialize/dispose cycles
      for (var i = 0; i < 5; i++) {
        await syncService.initialize();
        await syncService.addActivity(testActivity);
        syncService.dispose();
      }
      
      // Verify no lingering resources
      expect(syncService._syncTimer, isNull);
      expect(syncService._connectivitySubscription, isNull);
      expect(syncService._pendingOperations.isEmpty, true);
      
      // Verify no sync attempts after final disposal
      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 100));
      verifyNever(mockFirebaseService.logEmissions(any, any));
    });

    test('should handle disposal during network transition', () async {
      // Start with network available
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => true);
      await syncService.addActivity(testActivity);
      
      // Simulate network loss
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => false);
      connectivityStreamController.add(ConnectivityResult.none);
      
      // Dispose during network transition
      syncService.dispose();
      
      // Simulate network restoration
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => true);
      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verify no sync attempts after disposal
      verifyNever(mockFirebaseService.logEmissions(any, any));
    });

    test('should release network listener resources', () async {
      // Initialize service
      await syncService.initialize();
      
      // Verify network listener is active
      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 100));
      verify(mockNetworkChecker.hasConnection()).called(greaterThan(0));
      
      // Dispose service
      syncService.dispose();
      
      // Reset call count
      clearInteractions(mockNetworkChecker);
      
      // Verify network listener is inactive
      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 100));
      verifyNever(mockNetworkChecker.hasConnection());
    });

    test('should verify no memory leaks after disposal', () async {
      // Create references to resources
      await syncService.initialize();
      await syncService.addActivity(testActivity);
      
      // Store resource references
      final timer = syncService._syncTimer;
      final subscription = syncService._connectivitySubscription;
      final operations = List.from(syncService._pendingOperations);
      
      // Dispose service
      syncService.dispose();
      
      // Verify resources are properly cleaned up
      expect(timer?.isActive, false);
      expect(subscription, isNull);
      expect(syncService._pendingOperations.isEmpty, true);
      
      // Attempt to trigger disposed resources
      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verify no interactions with disposed resources
      verifyNever(mockFirebaseService.logEmissions(any, any));
      verifyNoMoreInteractions(mockNetworkChecker);
    });
  });

  group('SyncService - Operation Queue Management', () {
    setUp(() async {
      await syncService.initialize();
    });

    test('should add operations to queue', () async {
      await syncService.addActivity(testActivity);
      
      // Access private field for testing
      expect(syncService._pendingOperations.length, 1);
      expect(syncService._pendingOperations.first.activity.id, testActivity.id);
      expect(syncService._pendingOperations.first.type.toString(), '_SyncOperationType.add');
    });

    test('should deduplicate operations for same activity', () async {
      final updatedActivity = EcoActivity(
        id: testActivity.id,
        userId: testActivity.userId,
        type: 'updated-type',
        amount: 20.0,
        date: DateTime(2023, 1, 2),
        description: 'Updated activity',
        category: 'work',
      );

      await syncService.addActivity(testActivity);
      await syncService.updateActivity(updatedActivity);

      expect(syncService._pendingOperations.length, 1);
      expect(syncService._pendingOperations.first.activity.id, testActivity.id);
      expect(syncService._pendingOperations.first.type.toString(), '_SyncOperationType.update');
    });

    test('should maintain queue order', () async {
      final activity2 = EcoActivity(
        id: 'test-id-2',
        userId: 'user-1',
        type: 'transport',
        amount: 15.0,
        date: DateTime(2023, 1, 2),
        description: 'Second activity',
        category: 'transport',
      );

      final activity3 = EcoActivity(
        id: 'test-id-3',
        userId: 'user-1',
        type: 'energy',
        amount: 25.0,
        date: DateTime(2023, 1, 3),
        description: 'Third activity',
        category: 'home',
      );

      await syncService.addActivity(testActivity);
      await syncService.addActivity(activity2);
      await syncService.addActivity(activity3);

      expect(syncService._pendingOperations.length, 3);
      expect(syncService._pendingOperations[0].activity.id, 'test-id-1');
      expect(syncService._pendingOperations[1].activity.id, 'test-id-2');
      expect(syncService._pendingOperations[2].activity.id, 'test-id-3');
    });

    test('should persist queue across sync attempts', () async {
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => false);
      
      await syncService.addActivity(testActivity);
      expect(syncService._pendingOperations.length, 1);

      // Simulate network becoming available but sync failing
      when(mockNetworkChecker.hasConnection()).thenAnswer((_) async => true);
      when(mockFirebaseService.logEmissions(any, any))
          .thenThrow(Exception('Sync failed'));

      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 100));

      // Queue should still contain the operation after failed sync
      expect(syncService._pendingOperations.length, 1);
      expect(syncService._pendingOperations.first.activity.id, testActivity.id);
    });

    test('should remove operations from queue after successful sync', () async {
      await syncService.addActivity(testActivity);
      expect(syncService._pendingOperations.length, 1);

      // Simulate successful sync
      connectivityStreamController.add(ConnectivityResult.wifi);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(syncService._pendingOperations.isEmpty, true);
    });
  });
}
