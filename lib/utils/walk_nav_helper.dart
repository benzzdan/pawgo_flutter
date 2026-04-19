// Navigation helpers for walk completion events.
// Extracted for testability (US-001).

/// Returns true when the walk_completed Realtime callback should pop the
/// current route (returning to the MainShell with the bottom nav bar).
///
/// Walkers pop back to the MainShell. Owners do not pop — they see the
/// review bottom sheet instead.
///
/// [alreadyEnding] guards against double-pop: when `_endWalk()` or
/// `_performAutoEnd()` already called Navigator.pop(), the Realtime
/// callback must skip the pop to avoid removing the MainShell from the
/// navigation stack (which causes the bottom nav bar to disappear).
bool shouldPopOnWalkCompletion({
  required bool isWalker,
  bool alreadyEnding = false,
}) =>
    isWalker && !alreadyEnding;
