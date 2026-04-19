/// Pure validation helpers for booking form fields.
class BookingValidators {
  /// Validates that the scheduled date is a non-null future date.
  ///
  /// Returns a human-readable error message if invalid, or `null` if valid.
  static String? validateScheduledDate(DateTime? scheduledAt) {
    if (scheduledAt == null) {
      return 'Please select a date and time for your walk';
    }
    if (scheduledAt.isBefore(DateTime.now())) {
      return 'Please select a date in the future for your walk';
    }
    return null;
  }
}
