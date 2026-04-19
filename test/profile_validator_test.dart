import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/validators/profile_validator.dart';

void main() {
  group('ProfileValidator.validateFullName', () {
    test('returns error when name is empty', () {
      expect(
        ProfileValidator.validateFullName(''),
        'Name cannot be empty',
      );
    });

    test('returns error when name is only whitespace', () {
      expect(
        ProfileValidator.validateFullName('   '),
        'Name cannot be empty',
      );
    });

    test('returns error when name is too short', () {
      expect(
        ProfileValidator.validateFullName('A'),
        'Name must be at least 2 characters',
      );
    });

    test('returns error when name exceeds max length', () {
      final longName = 'A' * 101;
      expect(
        ProfileValidator.validateFullName(longName),
        'Name must be 100 characters or fewer',
      );
    });

    test('returns null for valid name', () {
      expect(ProfileValidator.validateFullName('John Doe'), isNull);
    });

    test('returns null for name at minimum length', () {
      expect(ProfileValidator.validateFullName('Jo'), isNull);
    });

    test('returns null for name at maximum length', () {
      final maxName = 'A' * 100;
      expect(ProfileValidator.validateFullName(maxName), isNull);
    });
  });

  group('ProfileValidator.validateUsername', () {
    test('returns error when username is empty', () {
      expect(
        ProfileValidator.validateUsername(''),
        'Username cannot be empty',
      );
    });

    test('returns error when username is only whitespace', () {
      expect(
        ProfileValidator.validateUsername('   '),
        'Username cannot be empty',
      );
    });

    test('returns error when username is too short', () {
      expect(
        ProfileValidator.validateUsername('ab'),
        'Username must be at least 3 characters',
      );
    });

    test('returns error when username exceeds max length', () {
      final longUsername = 'a' * 31;
      expect(
        ProfileValidator.validateUsername(longUsername),
        'Username must be 30 characters or fewer',
      );
    });

    test('returns error when username contains spaces', () {
      expect(
        ProfileValidator.validateUsername('user name'),
        'Username can only contain letters, numbers, and underscores',
      );
    });

    test('returns error when username contains special characters', () {
      expect(
        ProfileValidator.validateUsername('user@name'),
        'Username can only contain letters, numbers, and underscores',
      );
    });

    test('returns error when username starts with a number', () {
      expect(
        ProfileValidator.validateUsername('1username'),
        'Username must start with a letter',
      );
    });

    test('returns error when username starts with underscore', () {
      expect(
        ProfileValidator.validateUsername('_username'),
        'Username must start with a letter',
      );
    });

    test('returns null for valid username', () {
      expect(ProfileValidator.validateUsername('john_doe'), isNull);
    });

    test('returns null for username with numbers', () {
      expect(ProfileValidator.validateUsername('john123'), isNull);
    });

    test('returns null for username at minimum length', () {
      expect(ProfileValidator.validateUsername('abc'), isNull);
    });

    test('returns null for username at maximum length', () {
      final maxUsername = 'a' * 30;
      expect(ProfileValidator.validateUsername(maxUsername), isNull);
    });
  });
}
