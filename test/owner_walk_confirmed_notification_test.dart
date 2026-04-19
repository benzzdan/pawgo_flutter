import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/utils/booking_notification_helpers.dart';

// ---------------------------------------------------------------------------
// Tests for US-009: Owner in-app notification on walk acceptance
//
// The pure function `shouldShowOwnerConfirmation` returns true only when the
// new booking status is 'confirmed' AND the current user is the owner.
// ---------------------------------------------------------------------------

void main() {
  group('shouldShowOwnerConfirmation', () {
    test('returns true when status is confirmed and user is owner', () {
      expect(shouldShowOwnerConfirmation('confirmed', true), isTrue);
    });

    test('returns false when status is confirmed but user is NOT owner', () {
      expect(shouldShowOwnerConfirmation('confirmed', false), isFalse);
    });

    test('returns false when user is owner but status is not confirmed', () {
      expect(shouldShowOwnerConfirmation('pending', true), isFalse);
      expect(shouldShowOwnerConfirmation('walk_started', true), isFalse);
      expect(shouldShowOwnerConfirmation('walk_completed', true), isFalse);
      expect(shouldShowOwnerConfirmation('cancelled', true), isFalse);
      expect(
          shouldShowOwnerConfirmation('pending_walker_acceptance', true), isFalse);
    });

    test('returns false when both status is wrong and user is not owner', () {
      expect(shouldShowOwnerConfirmation('pending', false), isFalse);
      expect(shouldShowOwnerConfirmation('walk_started', false), isFalse);
    });
  });
}
