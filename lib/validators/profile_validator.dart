/// Validation logic for profile fields (name, username).
///
/// All methods return `null` on success, or an error message string on failure.
class ProfileValidator {
  static const int _minNameLength = 2;
  static const int _maxNameLength = 100;
  static const int _minUsernameLength = 3;
  static const int _maxUsernameLength = 30;

  /// Allowed characters: letters, digits, underscores.
  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$');

  /// Validates a full name.
  /// Returns `null` if valid, or an error message if not.
  static String? validateFullName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Name cannot be empty';
    }
    if (trimmed.length < _minNameLength) {
      return 'Name must be at least $_minNameLength characters';
    }
    if (trimmed.length > _maxNameLength) {
      return 'Name must be $_maxNameLength characters or fewer';
    }
    return null;
  }

  /// Validates a username.
  /// Returns `null` if valid, or an error message if not.
  static String? validateUsername(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Username cannot be empty';
    }
    if (trimmed.length < _minUsernameLength) {
      return 'Username must be at least $_minUsernameLength characters';
    }
    if (trimmed.length > _maxUsernameLength) {
      return 'Username must be $_maxUsernameLength characters or fewer';
    }
    // Check starts with a letter before the full pattern,
    // so we can give a more specific error message.
    if (!RegExp(r'^[a-zA-Z]').hasMatch(trimmed)) {
      return 'Username must start with a letter';
    }
    if (!_usernamePattern.hasMatch(trimmed)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }
}
