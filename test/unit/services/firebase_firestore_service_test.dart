import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:eco_tracker/src/core/models/eco_activity.dart';
import 'package:eco_tracker/src/core/models/user_profile.dart';
import 'package:eco_tracker/src/core/services/firebase_firestore_service.dart';

// Mock classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference {}
class MockDocumentReference extends Mock implements DocumentReference {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot {}
class MockQuerySnapshot extends Mock implements QuerySnapshot {}
class MockQuery extends Mock implements Query {}
class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot {}

void main() {
  late FirebaseFirestoreService firestoreService;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockUsersCollection;
  late MockCollectionReference mockActivitiesCollection;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockUsersCollection = MockCollectionReference();
    mockActivitiesCollection = MockCollectionReference();

    when(() => mockFirestore.collection('users'))
        .thenReturn(mockUsersCollection);
    when(() => mockFirestore.collection('activities'))
        .thenReturn(mockActivitiesCollection);

    firestoreService = FirebaseFirestoreService(firestore: mockFirestore);
  });

  group('FirebaseFirestoreService', () {
    group('User Profile Operations', () {
      test('setUserProfile updates user document', () async {
        final mockDocRef = MockDocumentReference();
        final userProfile = UserProfile(
          id: 'test-user-id',
          email: 'test@example.com',
          displayName: 'Test User',
        );

        when(() => mockUsersCollection.doc(userProfile.id))
            .thenReturn(mockDocRef);
        when(() => mockDocRef.set(any(), any())).thenAnswer((_) async {});

        await firestoreService.setUserProfile(userProfile);

        verify(() => mockDocRef.set(
              userProfile.toFirestore(),
              any(that: isA<SetOptions>()),
            )).called(1);
      });

      test('getUserProfile returns user profile when exists', () async {
        final mockDocRef = MockDocumentReference();
        final mockDocSnapshot = MockDocumentSnapshot();
        final userData = {
          'email': 'test@example.com',
          'displayName': 'Test User',
          'preferences': {},
        };

        when(() => mockUsersCollection.doc('test-user-id'))
            .thenReturn(mockDocRef);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.data()).thenReturn(userData);
        when(() => mockDocSnapshot.id).thenReturn('test-user-id');

        final result = await firestoreService.getUserProfile('test-user-id');

        expect(result, isNotNull);
        expect(result?.email, equals('test@example.com'));
        expect(result?.displayName, equals('Test User'));
      });
    });

    group('Eco Activity Operations', () {
      test('createEcoActivity returns activity ID', () async {
        final mockDocRef = MockDocumentReference();
        final activity = EcoActivity(
          id: '',
          userId: 'test-user-id',
          type: 'recycling',
          amount: 10.0,
          date: DateTime.now(),
        );

        when(() => mockActivitiesCollection.add(any()))
            .thenAnswer((_) async => mockDocRef);
        when(() => mockDocRef.id).thenReturn('new-activity-id');

        final result = await firestoreService.createEcoActivity(activity);

        expect(result, equals('new-activity-id'));
        verify(() => mockActivitiesCollection.add(activity.toFirestore()))
            .called(1);
      });

      test('updateEcoActivity updates activity document', () async {
        final mockDocRef = MockDocumentReference();
        final activity = EcoActivity(
          id: 'test-activity-id',
          userId: 'test-user-id',
          type: 'recycling',
          amount: 10.0,
          date: DateTime.now(),
        );

        when(() => mockActivitiesCollection.doc(activity.id))
            .thenReturn(mockDocRef);
        when(() => mockDocRef.update(any())).thenAnswer((_) async {});

        await firestoreService.updateEcoActivity(activity);

        verify(() => mockDocRef.update(activity.toFirestore())).called(1);
      });

      test('deleteEcoActivity deletes activity document', () async {
        final mockDocRef = MockDocumentReference();
        final activityId = 'test-activity-id';

        when(() => mockActivitiesCollection.doc(activityId))
            .thenReturn(mockDocRef);
        when(() => mockDocRef.delete()).thenAnswer((_) async {});

        await firestoreService.deleteEcoActivity(activityId);

        verify(() => mockDocRef.delete()).called(1);
      });

      test('queryEcoActivities returns filtered activities', () async {
        final mockQuery = MockQuery();
        final mockQuerySnapshot = MockQuerySnapshot();
        final mockQueryDocSnapshot = MockQueryDocumentSnapshot();
        final activityData = {
          'userId': 'test-user-id',
          'type': 'recycling',
          'amount': 10.0,
          'date': Timestamp.now(),
        };

        when(() => mockActivitiesCollection.where('userId',
                isEqualTo: 'test-user-id'))
            .thenReturn(mockQuery);
        when(() => mockQuery.where('type', isEqualTo: 'recycling'))
            .thenReturn(mockQuery);
        when(() => mockQuery.orderBy('date', descending: true))
            .thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(() => mockQuerySnapshot.docs).thenReturn([mockQueryDocSnapshot]);
        when(() => mockQueryDocSnapshot.data())
            .thenReturn(activityData);
        when(() => mockQueryDocSnapshot.id).thenReturn('test-activity-id');

        final results = await firestoreService.queryEcoActivities(
          userId: 'test-user-id',
          type: 'recycling',
        );

        expect(results, isNotEmpty);
        expect(results.first.type, equals('recycling'));
        expect(results.first.userId, equals('test-user-id'));
      });
    });

    group('User Preferences Operations', () {
      test('updateUserPreferences updates preferences', () async {
        final mockDocRef = MockDocumentReference();
        final userId = 'test-user-id';
        final preferences = {'theme': 'dark', 'notifications': true};

        when(() => mockUsersCollection.doc(userId)).thenReturn(mockDocRef);
        when(() => mockDocRef.update(any())).thenAnswer((_) async {});

        await firestoreService.updateUserPreferences(userId, preferences);

        verify(() => mockDocRef.update(any(
          that: predicate((Map<String, dynamic> data) =>
              data.containsKey('preferences') &&
              data.containsKey('lastActive')),
        ))).called(1);
      });
    });
  });
}