/// Returns `true` when a walker's Walk Request screen should auto-exit
/// because the owner cancelled the booking.
///
/// Guards against duplicate navigation via the [alreadyCancelled] flag.
bool shouldAutoExitOnCancellation({
  required String newStatus,
  required bool isWalkerScreen,
  required bool alreadyCancelled,
}) {
  if (alreadyCancelled) return false;
  if (!isWalkerScreen) return false;
  return newStatus == 'cancelled';
}
