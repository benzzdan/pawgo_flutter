/// Returns `true` if the owner's en-route map (showing walker approaching
/// home) should be displayed for the given booking [status].
///
/// The map is shown during `confirmed` and `walker_en_route` — the phases
/// where the walker is heading to the owner's home but hasn't started the
/// walk yet.
bool shouldShowEnRouteMap(String status) {
  return enRouteMapStatuses.contains(status);
}

/// Statuses during which the owner en-route map is visible.
const enRouteMapStatuses = <String>[
  'confirmed',
  'walker_en_route',
];
