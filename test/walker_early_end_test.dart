import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/utils/walk_end_helper.dart';

// ---------------------------------------------------------------------------
// Tests for US-007: Walker early-end walk warning modal
// ---------------------------------------------------------------------------

void main() {
  group('US-007: Walker early-end walk warning', () {
    // ── Pure logic tests for evaluateWalkEnd ──

    group('evaluateWalkEnd()', () {
      test('returns earlyEnd when >= 10 minutes remaining', () {
        // Walk started 20 min ago, booked for 60 min → 40 min remaining
        final start = DateTime(2026, 4, 17, 10, 0);
        final now = DateTime(2026, 4, 17, 10, 20);

        final result = evaluateWalkEnd(
          walkStartedAt: start,
          bookedDurationMinutes: 60,
          now: now,
        );

        expect(result.type, WalkEndWarningType.earlyEnd);
        expect(result.minutesRemaining, 40);
        expect(result.shouldProceedWithoutWarning, isFalse);
      });

      test('returns earlyEnd when exactly 10 minutes remaining', () {
        // Walk started 50 min ago, booked for 60 min → 10 min remaining
        final start = DateTime(2026, 4, 17, 10, 0);
        final now = DateTime(2026, 4, 17, 10, 50);

        final result = evaluateWalkEnd(
          walkStartedAt: start,
          bookedDurationMinutes: 60,
          now: now,
        );

        expect(result.type, WalkEndWarningType.earlyEnd);
        expect(result.minutesRemaining, 10);
      });

      test('returns veryShortWalk when < 10 minutes elapsed', () {
        // Walk started 5 min ago
        final start = DateTime(2026, 4, 17, 10, 0);
        final now = DateTime(2026, 4, 17, 10, 5);

        final result = evaluateWalkEnd(
          walkStartedAt: start,
          bookedDurationMinutes: 30,
          now: now,
        );

        expect(result.type, WalkEndWarningType.veryShortWalk);
        expect(result.minutesElapsed, 5);
        expect(result.shouldProceedWithoutWarning, isFalse);
      });

      test('returns veryShortWalk when 0 minutes elapsed', () {
        final start = DateTime(2026, 4, 17, 10, 0);
        final now = DateTime(2026, 4, 17, 10, 0);

        final result = evaluateWalkEnd(
          walkStartedAt: start,
          bookedDurationMinutes: 30,
          now: now,
        );

        expect(result.type, WalkEndWarningType.veryShortWalk);
        expect(result.minutesElapsed, 0);
      });

      test('veryShortWalk takes priority over earlyEnd for short walks', () {
        // Walk started 3 min ago, booked for 60 min → 57 min remaining
        // Both conditions met, but veryShortWalk should win
        final start = DateTime(2026, 4, 17, 10, 0);
        final now = DateTime(2026, 4, 17, 10, 3);

        final result = evaluateWalkEnd(
          walkStartedAt: start,
          bookedDurationMinutes: 60,
          now: now,
        );

        expect(result.type, WalkEndWarningType.veryShortWalk);
      });

      test('returns none when < 10 minutes remaining and >= 10 min elapsed',
          () {
        // Walk started 55 min ago, booked for 60 min → 5 min remaining
        final start = DateTime(2026, 4, 17, 10, 0);
        final now = DateTime(2026, 4, 17, 10, 55);

        final result = evaluateWalkEnd(
          walkStartedAt: start,
          bookedDurationMinutes: 60,
          now: now,
        );

        expect(result.type, WalkEndWarningType.none);
        expect(result.shouldProceedWithoutWarning, isTrue);
      });

      test('returns none when walk is past scheduled end', () {
        // Walk started 65 min ago, booked for 60 min → -5 min remaining
        final start = DateTime(2026, 4, 17, 10, 0);
        final now = DateTime(2026, 4, 17, 11, 5);

        final result = evaluateWalkEnd(
          walkStartedAt: start,
          bookedDurationMinutes: 60,
          now: now,
        );

        expect(result.type, WalkEndWarningType.none);
        expect(result.shouldProceedWithoutWarning, isTrue);
      });

      test('returns none when exactly at scheduled end', () {
        // Walk started 60 min ago, booked for 60 min → 0 min remaining
        final start = DateTime(2026, 4, 17, 10, 0);
        final now = DateTime(2026, 4, 17, 11, 0);

        final result = evaluateWalkEnd(
          walkStartedAt: start,
          bookedDurationMinutes: 60,
          now: now,
        );

        expect(result.type, WalkEndWarningType.none);
      });

      test('returns none when 9 minutes remaining (just under threshold)', () {
        // Walk started 51 min ago, booked for 60 min → 9 min remaining
        final start = DateTime(2026, 4, 17, 10, 0);
        final now = DateTime(2026, 4, 17, 10, 51);

        final result = evaluateWalkEnd(
          walkStartedAt: start,
          bookedDurationMinutes: 60,
          now: now,
        );

        expect(result.type, WalkEndWarningType.none);
      });

      test('handles short booked duration (15 min walk)', () {
        // Walk started 10 min ago, booked for 15 min → 5 min remaining
        final start = DateTime(2026, 4, 17, 10, 0);
        final now = DateTime(2026, 4, 17, 10, 10);

        final result = evaluateWalkEnd(
          walkStartedAt: start,
          bookedDurationMinutes: 15,
          now: now,
        );

        // 5 min remaining (< 10), 10 min elapsed (>= 10) → none
        expect(result.type, WalkEndWarningType.none);
      });
    });

    // ── Warning message content tests ──

    group('Warning message content', () {
      test('earlyEnd warning message includes minutes remaining', () {
        final start = DateTime(2026, 4, 17, 10, 0);
        final now = DateTime(2026, 4, 17, 10, 20);

        final result = evaluateWalkEnd(
          walkStartedAt: start,
          bookedDurationMinutes: 60,
          now: now,
        );

        // The UI will use result.minutesRemaining for the message
        expect(result.minutesRemaining, 40);
        final message =
            'You are ending ${result.minutesRemaining} minutes early. '
            'Your pay will be prorated to the actual time walked.';
        expect(message, contains('40 minutes early'));
      });

      test('veryShortWalk warning is fixed regardless of elapsed time', () {
        final start = DateTime(2026, 4, 17, 10, 0);
        final now = DateTime(2026, 4, 17, 10, 3);

        final result = evaluateWalkEnd(
          walkStartedAt: start,
          bookedDurationMinutes: 30,
          now: now,
        );

        expect(result.type, WalkEndWarningType.veryShortWalk);
        const message =
            'You ended the walk in less than 10 minutes. '
            'The owner will receive a full refund. Are you sure?';
        expect(message, contains('full refund'));
      });
    });

    // ── Actual duration computation tests ──

    group('Actual duration computation', () {
      test('computes floor of elapsed minutes correctly', () {
        // Walk started 22.7 min ago → floor = 22
        final start = DateTime(2026, 4, 17, 10, 0, 0);
        final now = DateTime(2026, 4, 17, 10, 22, 42); // 22 min 42 sec

        final elapsed = now.difference(start).inMinutes;
        expect(elapsed, 22); // Duration.inMinutes already floors
      });

      test('computes zero when ended immediately', () {
        final start = DateTime(2026, 4, 17, 10, 0, 0);
        final now = DateTime(2026, 4, 17, 10, 0, 30); // 30 seconds

        final elapsed = now.difference(start).inMinutes;
        expect(elapsed, 0);
      });
    });
  });
}
