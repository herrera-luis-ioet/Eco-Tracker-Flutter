import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import '../../../lib/src/core/services/local_storage_service.dart';
import '../../../lib/src/core/models/eco_activity.dart';

@GenerateMocks([Box, HiveInterface])
void main() {
  late LocalStorageService localStorageService;
  late Box<EcoActivity> mockBox;
  late HiveInterface mockHive;

  final testActivity = EcoActivity(
    id: 'test-id-1',
    userId: 'user-1',
    type: 'recycling',
    amount: 10.0,
    date: DateTime(2023, 1, 1),
    description: 'Test activity',
    category: 'home',
  );

  final testActivities = [
    testActivity,
    EcoActivity(
      id: 'test-id-2',
      userId: 'user-1',
      type: 'energy_saving',
      amount: 20.0,
      date: DateTime(2023, 1, 2),
    ),
    EcoActivity(
      id: 'test-id-3',
      userId: 'user-2',
      type: 'water_saving',
      amount: 30.0,
      date: DateTime(2023, 1, 3),
    ),
  ];

  setUp(() async {
    mockBox = MockBox();
    mockHive = MockHiveInterface();
    localStorageService = LocalStorageService();

    // Setup Hive mock
    when(mockHive.initFlutter()).thenAnswer((_) async {});
    when(mockHive.registerAdapter(any)).thenAnswer((_) {});
    when(mockHive.openBox<EcoActivity>('eco_activities'))
        .thenAnswer((_) async => mockBox);

    // Inject mock Hive
    Hive = mockHive;
  });

  group('LocalStorageService - Initialization', () {
    test('initialize should setup Hive correctly', () async {
      await localStorageService.initialize();

      verify(mockHive.initFlutter()).called(1);
      verify(mockHive.registerAdapter(any)).called(1);
      verify(mockHive.openBox<EcoActivity>('eco_activities')).called(1);
    });
  });

  group('LocalStorageService - CRUD Operations', () {
    setUp(() async {
      await localStorageService.initialize();
    });

    test('saveActivity should store activity successfully', () async {
      when(mockBox.put(testActivity.id, testActivity))
          .thenAnswer((_) async => {});

      final result = await localStorageService.saveActivity(testActivity);

      expect(result, true);
      verify(mockBox.put(testActivity.id, testActivity)).called(1);
    });

    test('saveActivity should handle errors gracefully', () async {
      when(mockBox.put(testActivity.id, testActivity))
          .thenThrow(Exception('Test error'));

      final result = await localStorageService.saveActivity(testActivity);

      expect(result, false);
    });

    test('getActivity should retrieve activity by id', () async {
      when(mockBox.get(testActivity.id)).thenReturn(testActivity);

      final result = await localStorageService.getActivity(testActivity.id);

      expect(result, equals(testActivity));
      verify(mockBox.get(testActivity.id)).called(1);
    });

    test('getActivity should return null when activity not found', () async {
      when(mockBox.get(testActivity.id)).thenReturn(null);

      final result = await localStorageService.getActivity(testActivity.id);

      expect(result, isNull);
    });

    test('getUserActivities should return user activities', () async {
      when(mockBox.values).thenReturn(testActivities);

      final result = await localStorageService.getUserActivities('user-1');

      expect(result.length, equals(2));
      expect(result.every((activity) => activity.userId == 'user-1'), true);
    });

    test('deleteActivity should remove activity successfully', () async {
      when(mockBox.delete(testActivity.id)).thenAnswer((_) async => {});

      final result = await localStorageService.deleteActivity(testActivity.id);

      expect(result, true);
      verify(mockBox.delete(testActivity.id)).called(1);
    });

    test('updateActivity should modify existing activity', () async {
      when(mockBox.put(testActivity.id, testActivity))
          .thenAnswer((_) async => {});

      final result = await localStorageService.updateActivity(testActivity);

      expect(result, true);
      verify(mockBox.put(testActivity.id, testActivity)).called(1);
    });
  });

  group('LocalStorageService - Bulk Operations', () {
    setUp(() async {
      await localStorageService.initialize();
    });

    test('bulkSaveActivities should store multiple activities', () async {
      when(mockBox.putAll(any)).thenAnswer((_) async => {});

      final result = await localStorageService.bulkSaveActivities(testActivities);

      expect(result, equals(testActivities.length));
      verify(mockBox.putAll(any)).called(1);
    });

    test('deleteUserActivities should remove all user activities', () async {
      when(mockBox.values).thenReturn(testActivities);
      when(mockBox.delete(any)).thenAnswer((_) async => {});

      final result = await localStorageService.deleteUserActivities('user-1');

      expect(result, equals(2));
      verify(mockBox.delete(any)).called(2);
    });

    test('clearAll should remove all activities', () async {
      when(mockBox.clear()).thenAnswer((_) async => 0);

      await localStorageService.clearAll();

      verify(mockBox.clear()).called(1);
    });
  });

  group('LocalStorageService - Error Handling', () {
    setUp(() async {
      await localStorageService.initialize();
    });

    test('bulkSaveActivities should handle errors gracefully', () async {
      when(mockBox.putAll(any)).thenThrow(Exception('Test error'));

      final result = await localStorageService.bulkSaveActivities(testActivities);

      expect(result, equals(0));
    });

    test('deleteUserActivities should handle errors gracefully', () async {
      when(mockBox.values).thenThrow(Exception('Test error'));

      final result = await localStorageService.deleteUserActivities('user-1');

      expect(result, equals(0));
    });

    test('clearAll should handle errors gracefully', () async {
      when(mockBox.clear()).thenThrow(Exception('Test error'));

      await expectLater(localStorageService.clearAll(), completes);
    });
  });
}