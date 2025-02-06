import 'package:flutter_test/flutter_test.dart';
import 'package:eco_tracker/src/core/models/eco_activity.dart';
import 'package:eco_tracker/src/core/exceptions/validation_exception.dart';

void main() {
  group('EcoActivity Validation Tests', () {
    final validDate = DateTime(2023, 1, 1);
    final validId = 'test-id-123';
    final validUserId = 'user-123';

    test('should create valid EcoActivity with required fields', () {
      final activity = EcoActivity(
        id: validId,
        userId: validUserId,
        type: 'emission',
        amount: 10.5,
        date: validDate,
      );

      expect(activity.id, equals(validId));
      expect(activity.userId, equals(validUserId));
      expect(activity.type, equals('emission'));
      expect(activity.amount, equals(10.5));
      expect(activity.date, equals(validDate));
      expect(activity.description, isNull);
      expect(activity.category, isNull);
    });

    test('should create valid EcoActivity with all fields', () {
      final activity = EcoActivity(
        id: validId,
        userId: validUserId,
        type: 'recycling',
        amount: 5.0,
        date: validDate,
        description: 'Test description',
        category: 'home',
      );

      expect(activity.description, equals('Test description'));
      expect(activity.category, equals('home'));
    });

    group('ID Validation', () {
      test('should throw ValidationException for empty ID', () {
        expect(
          () => EcoActivity(
            id: '',
            userId: validUserId,
            type: 'emission',
            amount: 10.0,
            date: validDate,
          ),
          throwsA(isA<ValidationException>()
              .having((e) => e.field, 'field', equals('id'))
              .having((e) => e.message, 'message', contains('cannot be empty'))),
        );
      });
    });

    group('User ID Validation', () {
      test('should throw ValidationException for empty userId', () {
        expect(
          () => EcoActivity(
            id: validId,
            userId: '',
            type: 'emission',
            amount: 10.0,
            date: validDate,
          ),
          throwsA(isA<ValidationException>()
              .having((e) => e.field, 'field', equals('userId'))
              .having((e) => e.message, 'message', contains('cannot be empty'))),
        );
      });
    });

    group('Type Validation', () {
      test('should accept all valid types', () {
        for (final type in EcoActivity.validTypes) {
          expect(
            () => EcoActivity(
              id: validId,
              userId: validUserId,
              type: type,
              amount: 10.0,
              date: validDate,
            ),
            returnsNormally,
          );
        }
      });

      test('should throw ValidationException for invalid type', () {
        expect(
          () => EcoActivity(
            id: validId,
            userId: validUserId,
            type: 'invalid_type',
            amount: 10.0,
            date: validDate,
          ),
          throwsA(isA<ValidationException>()
              .having((e) => e.field, 'field', equals('type'))),
        );
      });

      test('should accept valid type with different case', () {
        expect(
          () => EcoActivity(
            id: validId,
            userId: validUserId,
            type: 'EMISSION',
            amount: 10.0,
            date: validDate,
          ),
          returnsNormally,
        );
      });
    });

    group('Amount Validation', () {
      test('should throw ValidationException for negative amount', () {
        expect(
          () => EcoActivity(
            id: validId,
            userId: validUserId,
            type: 'emission',
            amount: -1.0,
            date: validDate,
          ),
          throwsA(isA<ValidationException>()
              .having((e) => e.field, 'field', equals('amount'))
              .having((e) => e.message, 'message', contains('cannot be negative'))),
        );
      });

      test('should throw ValidationException for infinite amount', () {
        expect(
          () => EcoActivity(
            id: validId,
            userId: validUserId,
            type: 'emission',
            amount: double.infinity,
            date: validDate,
          ),
          throwsA(isA<ValidationException>()
              .having((e) => e.field, 'field', equals('amount'))
              .having((e) => e.message, 'message', contains('valid number'))),
        );
      });

      test('should throw ValidationException for NaN amount', () {
        expect(
          () => EcoActivity(
            id: validId,
            userId: validUserId,
            type: 'emission',
            amount: double.nan,
            date: validDate,
          ),
          throwsA(isA<ValidationException>()
              .having((e) => e.field, 'field', equals('amount'))
              .having((e) => e.message, 'message', contains('valid number'))),
        );
      });
    });

    group('Date Validation', () {
      test('should throw ValidationException for future date', () {
        final futureDate = DateTime.now().add(const Duration(days: 1));
        expect(
          () => EcoActivity(
            id: validId,
            userId: validUserId,
            type: 'emission',
            amount: 10.0,
            date: futureDate,
          ),
          throwsA(isA<ValidationException>()
              .having((e) => e.field, 'field', equals('date'))
              .having((e) => e.message, 'message', contains('future'))),
        );
      });

      test('should throw ValidationException for date before 2000', () {
        final oldDate = DateTime(1999, 12, 31);
        expect(
          () => EcoActivity(
            id: validId,
            userId: validUserId,
            type: 'emission',
            amount: 10.0,
            date: oldDate,
          ),
          throwsA(isA<ValidationException>()
              .having((e) => e.field, 'field', equals('date'))
              .having((e) => e.message, 'message', contains('2000'))),
        );
      });
    });

    group('Description Validation', () {
      test('should throw ValidationException for empty description', () {
        expect(
          () => EcoActivity(
            id: validId,
            userId: validUserId,
            type: 'emission',
            amount: 10.0,
            date: validDate,
            description: '',
          ),
          throwsA(isA<ValidationException>()
              .having((e) => e.field, 'field', equals('description'))
              .having((e) => e.message, 'message', contains('cannot be empty'))),
        );
      });

      test('should throw ValidationException for description exceeding 500 characters', () {
        final longDescription = 'a' * 501;
        expect(
          () => EcoActivity(
            id: validId,
            userId: validUserId,
            type: 'emission',
            amount: 10.0,
            date: validDate,
            description: longDescription,
          ),
          throwsA(isA<ValidationException>()
              .having((e) => e.field, 'field', equals('description'))
              .having((e) => e.message, 'message', contains('500 characters'))),
        );
      });
    });

    group('Category Validation', () {
      test('should accept all valid categories', () {
        for (final category in EcoActivity.validCategories) {
          expect(
            () => EcoActivity(
              id: validId,
              userId: validUserId,
              type: 'emission',
              amount: 10.0,
              date: validDate,
              category: category,
            ),
            returnsNormally,
          );
        }
      });

      test('should throw ValidationException for invalid category', () {
        expect(
          () => EcoActivity(
            id: validId,
            userId: validUserId,
            type: 'emission',
            amount: 10.0,
            date: validDate,
            category: 'invalid_category',
          ),
          throwsA(isA<ValidationException>()
              .having((e) => e.field, 'field', equals('category'))),
        );
      });

      test('should accept valid category with different case', () {
        expect(
          () => EcoActivity(
            id: validId,
            userId: validUserId,
            type: 'emission',
            amount: 10.0,
            date: validDate,
            category: 'HOME',
          ),
          returnsNormally,
        );
      });
    });

    group('Data Sanitization', () {
      test('should sanitize input data correctly', () {
        final input = {
          'type': ' EMISSION ',
          'description': ' Test description ',
          'category': ' HOME ',
        };

        final sanitized = EcoActivity.sanitizeData(input);

        expect(sanitized['type'], equals('emission'));
        expect(sanitized['description'], equals('Test description'));
        expect(sanitized['category'], equals('home'));
      });

      test('should handle null values in sanitization', () {
        final input = {
          'type': 'emission',
          'description': null,
          'category': null,
        };

        final sanitized = EcoActivity.sanitizeData(input);

        expect(sanitized['type'], equals('emission'));
        expect(sanitized['description'], isNull);
        expect(sanitized['category'], isNull);
      });
    });

    group('copyWith Method', () {
      test('should create a valid copy with updated fields', () {
        final original = EcoActivity(
          id: validId,
          userId: validUserId,
          type: 'emission',
          amount: 10.0,
          date: validDate,
        );

        final copy = original.copyWith(
          amount: 20.0,
          type: 'recycling',
          description: 'New description',
        );

        expect(copy.id, equals(original.id));
        expect(copy.userId, equals(original.userId));
        expect(copy.type, equals('recycling'));
        expect(copy.amount, equals(20.0));
        expect(copy.date, equals(original.date));
        expect(copy.description, equals('New description'));
      });

      test('should validate the copied instance', () {
        final original = EcoActivity(
          id: validId,
          userId: validUserId,
          type: 'emission',
          amount: 10.0,
          date: validDate,
        );

        expect(
          () => original.copyWith(amount: -1.0),
          throwsA(isA<ValidationException>()
              .having((e) => e.field, 'field', equals('amount'))),
        );
      });
    });
  });
}