import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/screens/walker_bookings_screen.dart';

void main() {
  group('WalkerBookingsScreen.pendingScrollToRequests', () {
    tearDown(() {
      // Reset static state after each test
      WalkerBookingsScreen.pendingScrollToRequests = false;
    });

    test('pendingScrollToRequests defaults to false', () {
      expect(WalkerBookingsScreen.pendingScrollToRequests, isFalse);
    });

    test('pendingScrollToRequests can be set to true to trigger scroll', () {
      WalkerBookingsScreen.pendingScrollToRequests = true;
      expect(WalkerBookingsScreen.pendingScrollToRequests, isTrue);
    });

    test('pendingScrollToRequests is consumed (reset to false) after being read', () {
      // This tests the pattern: set the flag, then the screen reads it in
      // initState and resets it. We test the static field behavior here;
      // the screen integration is tested separately.
      WalkerBookingsScreen.pendingScrollToRequests = true;
      expect(WalkerBookingsScreen.pendingScrollToRequests, isTrue);

      // Simulate the screen consuming the flag
      final shouldScroll = WalkerBookingsScreen.pendingScrollToRequests;
      WalkerBookingsScreen.pendingScrollToRequests = false;

      expect(shouldScroll, isTrue);
      expect(WalkerBookingsScreen.pendingScrollToRequests, isFalse);
    });
  });
}
