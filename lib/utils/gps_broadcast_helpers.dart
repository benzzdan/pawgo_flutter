/// Returns `true` if GPS broadcasting should be active for the given
/// booking [status].
///
/// Broadcasting starts during `confirmed`, `walker_en_route`, and
/// `walk_started` phases so the owner can track the walker from the
/// moment the booking is confirmed.
bool shouldStartGpsBroadcast(String status) {
  return gpsBroadcastActiveStatuses.contains(status);
}

/// Statuses during which GPS broadcast should be active.
/// Exposed for use in Supabase queries (e.g. resumeIfActiveWalk).
const gpsBroadcastActiveStatuses = <String>[
  'confirmed',
  'walker_en_route',
  'walk_started',
];
