// Mocks file for sync_service_test.dart
import 'dart:async' as _i4;

import 'package:connectivity_plus/connectivity_plus.dart' as _i2;
import 'package:mockito/mockito.dart' as _i1;
import 'package:eco_tracker/src/core/services/firebase_service.dart' as _i5;
import 'package:eco_tracker/src/core/services/local_storage_service.dart' as _i6;
import 'package:eco_tracker/src/core/utils/network_checker.dart' as _i3;
import 'package:eco_tracker/src/core/models/eco_activity.dart' as _i7;

// FirebaseService mock
class MockFirebaseService extends _i1.Mock implements _i5.FirebaseService {
  @override
  Future<void> logEmissions(double amount, DateTime timestamp) =>
      (super.noSuchMethod(
        Invocation.method(
          #logEmissions,
          [amount, timestamp],
        ),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>);

  @override
  Future<void> deleteEmission(DateTime timestamp) =>
      (super.noSuchMethod(
        Invocation.method(
          #deleteEmission,
          [timestamp],
        ),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>);
}

// LocalStorageService mock
class MockLocalStorageService extends _i1.Mock implements _i6.LocalStorageService {
  @override
  Future<void> initialize() =>
      (super.noSuchMethod(
        Invocation.method(#initialize, []),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>);

  @override
  Future<bool> saveActivity(_i7.EcoActivity activity) =>
      (super.noSuchMethod(
        Invocation.method(#saveActivity, [activity]),
        returnValue: Future<bool>.value(true),
        returnValueForMissingStub: Future<bool>.value(true),
      ) as Future<bool>);

  @override
  Future<bool> updateActivity(_i7.EcoActivity activity) =>
      (super.noSuchMethod(
        Invocation.method(#updateActivity, [activity]),
        returnValue: Future<bool>.value(true),
        returnValueForMissingStub: Future<bool>.value(true),
      ) as Future<bool>);

  @override
  Future<bool> deleteActivity(String activityId) =>
      (super.noSuchMethod(
        Invocation.method(#deleteActivity, [activityId]),
        returnValue: Future<bool>.value(true),
        returnValueForMissingStub: Future<bool>.value(true),
      ) as Future<bool>);

  @override
  Future<_i7.EcoActivity?> getActivity(String activityId) =>
      (super.noSuchMethod(
        Invocation.method(#getActivity, [activityId]),
        returnValue: Future<_i7.EcoActivity?>.value(null),
        returnValueForMissingStub: Future<_i7.EcoActivity?>.value(null),
      ) as Future<_i7.EcoActivity?>);
}

// NetworkChecker mock
class MockNetworkChecker extends _i1.Mock implements _i3.NetworkChecker {
  @override
  Future<bool> hasConnection() =>
      (super.noSuchMethod(
        Invocation.method(#hasConnection, []),
        returnValue: Future<bool>.value(true),
        returnValueForMissingStub: Future<bool>.value(true),
      ) as Future<bool>);
}

// Connectivity mock
class MockConnectivity extends _i1.Mock implements _i2.Connectivity {
  @override
  Stream<_i2.ConnectivityResult> get onConnectivityChanged =>
      (super.noSuchMethod(
        Invocation.getter(#onConnectivityChanged),
        returnValue: Stream<_i2.ConnectivityResult>.empty(),
        returnValueForMissingStub: Stream<_i2.ConnectivityResult>.empty(),
      ) as Stream<_i2.ConnectivityResult>);
}