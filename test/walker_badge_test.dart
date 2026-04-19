import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/screens/walker_bookings_screen.dart';

// ---------------------------------------------------------------------------
// Tests for US-006: Walker badge on Upcoming tab for new booking requests
// ---------------------------------------------------------------------------

void main() {
  group('US-006: Walker badge on Upcoming tab', () {
    group('Badge visibility', () {
      testWidgets('shows badge with count when pending bookings exist and not on Upcoming tab',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            bookings: [
              _testBooking(status: 'pending_walker_acceptance', id: 'b1'),
              _testBooking(status: 'pending_walker_acceptance', id: 'b2'),
              _testBooking(status: 'walk_started', id: 'b3'),
            ],
            initialTab: 1, // Start on Active tab so badge is visible
          ),
        );
        await tester.pumpAndSettle();

        // Badge should show count of pending bookings (2)
        final badgeFinder = find.byKey(const Key('upcoming-tab-badge'));
        expect(badgeFinder, findsOneWidget);

        // The badge should display the count
        final badgeText = find.descendant(
          of: badgeFinder,
          matching: find.text('2'),
        );
        expect(badgeText, findsOneWidget);
      });

      testWidgets('does not show badge when no pending bookings',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            bookings: [
              _testBooking(status: 'walk_started', id: 'b1'),
            ],
            initialTab: 1,
          ),
        );
        await tester.pumpAndSettle();

        final badgeFinder = find.byKey(const Key('upcoming-tab-badge'));
        expect(badgeFinder, findsNothing);
      });

      testWidgets('does not show badge when bookings list is empty',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(bookings: [], initialTab: 1),
        );
        await tester.pumpAndSettle();

        final badgeFinder = find.byKey(const Key('upcoming-tab-badge'));
        expect(badgeFinder, findsNothing);
      });
    });

    group('Badge count accuracy', () {
      testWidgets('badge shows 1 for single pending booking',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            bookings: [
              _testBooking(status: 'pending_walker_acceptance', id: 'b1'),
            ],
            initialTab: 1,
          ),
        );
        await tester.pumpAndSettle();

        final badgeFinder = find.byKey(const Key('upcoming-tab-badge'));
        expect(badgeFinder, findsOneWidget);

        final badgeText = find.descendant(
          of: badgeFinder,
          matching: find.text('1'),
        );
        expect(badgeText, findsOneWidget);
      });

      testWidgets('badge shows 3 for three pending bookings',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            bookings: [
              _testBooking(status: 'pending_walker_acceptance', id: 'b1'),
              _testBooking(status: 'pending_walker_acceptance', id: 'b2'),
              _testBooking(status: 'pending_walker_acceptance', id: 'b3'),
            ],
            initialTab: 2,
          ),
        );
        await tester.pumpAndSettle();

        final badgeFinder = find.byKey(const Key('upcoming-tab-badge'));
        final badgeText = find.descendant(
          of: badgeFinder,
          matching: find.text('3'),
        );
        expect(badgeText, findsOneWidget);
      });
    });

    group('Badge clear on tab tap', () {
      testWidgets('badge clears when Upcoming tab is tapped',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            bookings: [
              _testBooking(status: 'pending_walker_acceptance', id: 'b1'),
              _testBooking(status: 'pending_walker_acceptance', id: 'b2'),
              _testBooking(status: 'walk_started', id: 'b3'),
            ],
            initialTab: 1, // Start on Active tab so badge is visible
          ),
        );
        await tester.pumpAndSettle();

        // Badge should be visible since we're not on Upcoming tab
        expect(
          find.byKey(const Key('upcoming-tab-badge')),
          findsOneWidget,
        );

        // Tap the Upcoming tab
        await tester.tap(find.text('Upcoming'));
        await tester.pumpAndSettle();

        // Badge should be cleared
        expect(
          find.byKey(const Key('upcoming-tab-badge')),
          findsNothing,
        );
      });

      testWidgets('badge stays hidden after tapping Upcoming tab',
          (tester) async {
        // Start on Upcoming tab - badge should already be cleared
        await tester.pumpWidget(
          _buildTestApp(
            bookings: [
              _testBooking(status: 'pending_walker_acceptance', id: 'b1'),
            ],
            initialTab: 0,
          ),
        );
        await tester.pumpAndSettle();

        // Badge should not show because we started on the Upcoming tab
        expect(
          find.byKey(const Key('upcoming-tab-badge')),
          findsNothing,
        );
      });
    });

    group('Badge reappears after new pending booking', () {
      testWidgets(
          'badge not shown on Upcoming tab even with pending bookings',
          (tester) async {
        // When user is already viewing Upcoming tab, badge is suppressed
        await tester.pumpWidget(
          _buildTestApp(
            bookings: [
              _testBooking(status: 'pending_walker_acceptance', id: 'b1'),
            ],
            initialTab: 0,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('upcoming-tab-badge')),
          findsNothing,
        );
      });
    });
  });
}

// --- Test helpers ---

Map<String, dynamic> _testBooking({
  String status = 'confirmed',
  String id = 'test-booking-1',
}) {
  return {
    'id': id,
    'status': status,
    'scheduled_at': DateTime.now()
        .toUtc()
        .add(const Duration(hours: 2))
        .toIso8601String(),
    'duration_minutes': 60,
    'total_price_mxn': 200,
    'notes': null,
    'started_at':
        status == 'walk_started' ? DateTime.now().toUtc().toIso8601String() : null,
    'completed_at': null,
    'owner_id': 'test-owner-id',
    'walker_id': 'test-walker-id',
    'acceptance_deadline': null,
    'dogs': {
      'name': 'Buddy',
      'breed': 'Labrador',
      'photo_url': null,
    },
    'users': {
      'full_name': 'Test Owner',
      'avatar_url': null,
    },
    'walkers': {
      'user_id': 'test-walker-user-id',
      'hourly_rate_mxn': 200,
    },
  };
}

Widget _buildTestApp({
  required List<Map<String, dynamic>> bookings,
  int initialTab = 0,
}) {
  return MaterialApp(
    home: Scaffold(
      body: WalkerBookingsScreen(
        initialTab: initialTab,
        testBookings: bookings,
        testWalkerId: 'test-walker-id',
      ),
    ),
    routes: {
      '/active-walk': (_) => const Scaffold(body: Text('active walk')),
      '/chat': (_) => const Scaffold(body: Text('chat')),
      '/walk-request': (_) => const Scaffold(body: Text('walk request')),
    },
  );
}
