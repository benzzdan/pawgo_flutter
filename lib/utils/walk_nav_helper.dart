// Navigation helpers for walk completion events.
// Extracted for testability (US-001).

/// Returns true when the walk_completed Realtime callback should pop the
/// current route (returning to the MainShell with the bottom nav bar).
///
/// Walkers pop back to the MainShell. Owners do not pop — they see the
/// review bottom sheet instead.
bool shouldPopOnWalkCompletion({required bool isWalker}) => isWalker;
