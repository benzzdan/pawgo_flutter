// Pure-logic helper for determining whether a walker is ending a walk early
// and what warning (if any) to show.
// Extracted from ActiveWalkScreen for testability (US-007).

/// The type of early-end warning to show, or [none] if the walk is ending
/// within the normal window.
enum WalkEndWarningType {
  /// Walk has >= 10 minutes remaining — pay will be prorated.
  earlyEnd,

  /// Less than 10 minutes have elapsed since the walk started — full refund.
  veryShortWalk,

  /// Walk is ending within the scheduled window — no warning needed.
  none,
}

/// Result of evaluating whether the walker is ending the walk early.
class WalkEndWarning {
  const WalkEndWarning({
    required this.type,
    this.minutesRemaining = 0,
    this.minutesElapsed = 0,
  });

  final WalkEndWarningType type;

  /// Minutes remaining in the scheduled walk (only meaningful for [earlyEnd]).
  final int minutesRemaining;

  /// Minutes elapsed since walk start (only meaningful for [veryShortWalk]).
  final int minutesElapsed;

  /// Convenience — true when no modal is needed.
  bool get shouldProceedWithoutWarning => type == WalkEndWarningType.none;
}

/// Determines the appropriate warning when a walker taps "End Walk".
///
/// [walkStartedAt] — when the walk actually started (from `started_at` column).
/// [bookedDurationMinutes] — the pre-booked duration in minutes.
/// [now] — injectable clock for testing; defaults to `DateTime.now()`.
WalkEndWarning evaluateWalkEnd({
  required DateTime walkStartedAt,
  required int bookedDurationMinutes,
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();
  final elapsedMinutes =
      currentTime.difference(walkStartedAt).inMinutes;
  final scheduledEnd =
      walkStartedAt.add(Duration(minutes: bookedDurationMinutes));
  final minutesRemaining =
      scheduledEnd.difference(currentTime).inMinutes;

  // Check very-short-walk first: < 10 minutes elapsed
  if (elapsedMinutes < 10) {
    return WalkEndWarning(
      type: WalkEndWarningType.veryShortWalk,
      minutesElapsed: elapsedMinutes,
    );
  }

  // Check early end: >= 10 minutes remaining
  if (minutesRemaining >= 10) {
    return WalkEndWarning(
      type: WalkEndWarningType.earlyEnd,
      minutesRemaining: minutesRemaining,
    );
  }

  // Normal end — within scheduled window
  return const WalkEndWarning(type: WalkEndWarningType.none);
}
