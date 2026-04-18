/// Tracks which booking's chat screen is currently open.
///
/// Parent screens (ActiveWalkScreen, WalkerChatListScreen) check
/// [isOnChat] before incrementing unread badge counts. This prevents
/// the badge from incrementing while the user is actively reading
/// messages on the chat screen.
///
/// Usage:
/// - Call [enterChat] in the chat screen's initState/didChangeDependencies
/// - Call [leaveChat] in the chat screen's dispose
/// - Check [isOnChat] in the parent realtime callback before incrementing
class ChatPresenceTracker {
  ChatPresenceTracker._();

  static final Set<String> _activeBookings = {};

  /// Mark this booking's chat as currently open.
  static void enterChat(String bookingId) {
    _activeBookings.add(bookingId);
  }

  /// Mark this booking's chat as closed.
  static void leaveChat(String bookingId) {
    _activeBookings.remove(bookingId);
  }

  /// Whether the user is currently viewing this booking's chat.
  static bool isOnChat(String bookingId) {
    return _activeBookings.contains(bookingId);
  }

  /// Reset all tracking state. Used in tests.
  static void clear() {
    _activeBookings.clear();
  }
}
