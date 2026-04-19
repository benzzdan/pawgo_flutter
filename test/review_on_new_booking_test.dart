import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/screens/bookings_screen.dart';
import 'package:pawgo/widgets/review_bottom_sheet.dart';

/// US-002: Creating a new booking must NEVER trigger the review/rating dialog.
///
/// Root cause: BookingsScreen._checkPendingReview() runs unconditionally after
/// _fetchBookings completes. When a booking is created, the app navigates to
/// the bookings tab with pendingInitialTab = 'upcoming'. If a previous
/// walk_completed booking exists without a review, the dialog fires — wrong.
///
/// Fix: skip the review check when BookingsScreen was opened with a
/// pendingInitialTab (indicating a programmatic navigation, not an organic
/// bottom-nav tap).
void main() {
  setUp(() {
    // Reset static state between tests
    ReviewBottomSheet.shownThisSession = false;
    BookingsScreen.pendingInitialTab = null;
  });

  group('US-002: Review dialog must not appear on new booking creation', () {
    test(
        'shouldCheckPendingReview returns false when pendingInitialTab is set',
        () {
      // Simulate booking creation flow: sets pendingInitialTab to 'upcoming'
      BookingsScreen.pendingInitialTab = 'upcoming';
      expect(BookingsScreen.shouldCheckPendingReview(), isFalse,
          reason:
              'Review check should be skipped when arriving from booking creation');
    });

    test(
        'shouldCheckPendingReview returns false when pendingInitialTab is "past"',
        () {
      // Simulate arriving from a review submission redirect
      BookingsScreen.pendingInitialTab = 'past';
      expect(BookingsScreen.shouldCheckPendingReview(), isFalse,
          reason:
              'Review check should be skipped on any programmatic navigation');
    });

    test(
        'shouldCheckPendingReview returns true when pendingInitialTab is null (organic nav)',
        () {
      // User taps the bookings tab in the bottom nav — normal flow
      BookingsScreen.pendingInitialTab = null;
      expect(BookingsScreen.shouldCheckPendingReview(), isTrue,
          reason:
              'Review check should run on organic navigation to bookings');
    });

    test(
        'shouldCheckPendingReview returns false when shownThisSession is already true',
        () {
      ReviewBottomSheet.shownThisSession = true;
      BookingsScreen.pendingInitialTab = null;
      expect(BookingsScreen.shouldCheckPendingReview(), isFalse,
          reason:
              'Review check should be skipped if already shown this session');
    });
  });
}
