// Tests for the VerificationOutcome value type used by WalkerVerificationService.
//
// The service itself launches a platform channel (Veriff SDK), which cannot
// be exercised in unit tests. What we *can* test is the outcome shape that
// the screen consumes — confirming the three kinds are distinguishable and
// carry the expected message payload.

import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/services/walker_verification_service.dart';

void main() {
  group('VerificationOutcome', () {
    test('submitted has no message', () {
      final outcome = VerificationOutcome.submitted();
      expect(outcome.kind, VerificationOutcomeKind.submitted);
      expect(outcome.message, isNull);
    });

    test('canceled has no message', () {
      final outcome = VerificationOutcome.canceled();
      expect(outcome.kind, VerificationOutcomeKind.canceled);
      expect(outcome.message, isNull);
    });

    test('error carries the message', () {
      final outcome = VerificationOutcome.error('camera_unavailable');
      expect(outcome.kind, VerificationOutcomeKind.error);
      expect(outcome.message, 'camera_unavailable');
    });

    test('factories are const-friendly for submitted/canceled', () {
      // submitted/canceled don't allocate per-call because they use
      // canonical const instances under the hood.
      expect(
        identical(VerificationOutcome.submitted(), VerificationOutcome.submitted()),
        isTrue,
      );
      expect(
        identical(VerificationOutcome.canceled(), VerificationOutcome.canceled()),
        isTrue,
      );
    });
  });
}
