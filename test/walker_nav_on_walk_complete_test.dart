import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/utils/walk_nav_helper.dart';

// ---------------------------------------------------------------------------
// Tests for US-001: Bottom nav bar disappears after ending a walk
//
// Root cause: when walk_completed fires via Realtime, the callback for
// the walker side called pushReplacementNamed('/walker-bookings') which
// pushes a standalone WalkerBookingsScreen *without* the MainShell
// wrapper, losing the bottom nav bar.
//
// Fix: on walk_completed, the walker should pop() back to the MainShell
// instead of pushing a new standalone route.
// ---------------------------------------------------------------------------

void main() {
  group('US-001: Walker navigation on walk_completed', () {
    group('shouldPopOnWalkCompletion()', () {
      test('returns true for walker — pop back to MainShell', () {
        // Walker tapping End Walk or server auto-ending should pop back to
        // MainShell (which has the bottom nav bar). NOT pushReplacementNamed.
        expect(shouldPopOnWalkCompletion(isWalker: true), isTrue);
      });

      test('returns false for owner — show review sheet instead', () {
        // Owner should NOT pop — they see the review bottom sheet, not a pop.
        expect(shouldPopOnWalkCompletion(isWalker: false), isFalse);
      });
    });
  });
}
