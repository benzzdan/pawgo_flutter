import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/utils/booking_validators.dart';

void main() {
  group('BookingValidators.validateScheduledDate', () {
    test('returns error message when date is in the past', () {
      final pastDate = DateTime.now().subtract(const Duration(hours: 2));
      final result = BookingValidators.validateScheduledDate(pastDate);
      expect(result, isNotNull);
      expect(result, 'Please select a date in the future for your walk');
    });

    test('returns error message when date is null', () {
      final result = BookingValidators.validateScheduledDate(null);
      expect(result, isNotNull);
      expect(result, 'Please select a date and time for your walk');
    });

    test('returns null when date is in the future', () {
      final futureDate = DateTime.now().add(const Duration(hours: 2));
      final result = BookingValidators.validateScheduledDate(futureDate);
      expect(result, isNull);
    });

    test('returns error message when date is just barely in the past', () {
      // A date 1 minute in the past should still fail
      final barelyPast = DateTime.now().subtract(const Duration(minutes: 1));
      final result = BookingValidators.validateScheduledDate(barelyPast);
      expect(result, isNotNull);
      expect(result, 'Please select a date in the future for your walk');
    });
  });
}
