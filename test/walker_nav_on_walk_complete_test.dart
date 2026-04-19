import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/utils/walk_nav_helper.dart';

// ---------------------------------------------------------------------------
// Tests for US-001: Bottom nav bar disappears after ending a walk
//
// Root cause #1: when walk_completed fires via Realtime, the callback for
// the walker side called pushReplacementNamed('/walker-bookings') which
// pushes a standalone WalkerBookingsScreen *without* the MainShell
// wrapper, losing the bottom nav bar.
//
// Fix #1: on walk_completed, the walker should pop() back to the MainShell
// instead of pushing a new standalone route.
//
// Root cause #2 (double-pop): Both _endWalk() and the Realtime callback
// call Navigator.pop(). The first pop returns to MainShell (correct), the
// second pop removes MainShell from the stack (bug). The Realtime callback
// must be suppressed when the walk was already ended locally.
//
// Fix #2: shouldPopOnWalkCompletion accepts alreadyEnding — when true
// (set by _endWalk / _performAutoEnd), the callback skips the pop.
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

      test('returns false for walker when walk already ending — prevents double pop', () {
        // When _endWalk() or _performAutoEnd() already called Navigator.pop(),
        // the Realtime callback must NOT pop again (double-pop loses MainShell).
        expect(
          shouldPopOnWalkCompletion(isWalker: true, alreadyEnding: true),
          isFalse,
        );
      });

      test('returns false for owner even when alreadyEnding', () {
        // Owner path always shows review sheet, regardless of ending state.
        expect(
          shouldPopOnWalkCompletion(isWalker: false, alreadyEnding: true),
          isFalse,
        );
      });
    });
  });
}
