/// Returns true when the owner should see a "walk confirmed" notification.
///
/// This fires when a walker accepts a booking, transitioning its status
/// to `confirmed`. Only the booking owner should see this notification.
bool shouldShowOwnerConfirmation(String newStatus, bool isOwner) {
  return newStatus == 'confirmed' && isOwner;
}
