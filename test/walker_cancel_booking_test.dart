import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/screens/walker_bookings_screen.dart';

// ---------------------------------------------------------------------------
// Tests for US-005: Walker cancel confirmed booking
// ---------------------------------------------------------------------------

void main() {
  group('US-005: Walker cancel confirmed booking', () {
    group('Cancel button visibility', () {
      testWidgets('shows Cancel button for confirmed booking',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(bookings: [_testBooking(status: 'confirmed')]),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cancel Booking'), findsOneWidget);
      });

      testWidgets('hides Cancel button for walk_started booking',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            bookings: [_testBooking(status: 'walk_started')],
            initialTab: 1,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cancel Booking'), findsNothing);
      });

      testWidgets('shows Cancel button for walker_en_route booking',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(bookings: [_testBooking(status: 'walker_en_route')]),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cancel Booking'), findsOneWidget);
      });
    });

    group('Confirmation dialog', () {
      testWidgets(
          'shows confirmation dialog mentioning owner notification',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(bookings: [_testBooking(status: 'confirmed')]),
        );
        await tester.pumpAndSettle();

        // Scroll Cancel Booking into view and tap
        await tester.ensureVisible(find.text('Cancel Booking'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel Booking'));
        await tester.pumpAndSettle();

        expect(find.text('Cancel Booking?'), findsOneWidget);
        expect(
          find.textContaining('owner will be notified'),
          findsOneWidget,
        );
      });

      testWidgets('dismisses dialog when Keep is tapped', (tester) async {
        await tester.pumpWidget(
          _buildTestApp(bookings: [_testBooking(status: 'confirmed')]),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Cancel Booking'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel Booking'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Keep'));
        await tester.pumpAndSettle();

        expect(find.text('Cancel Booking?'), findsNothing);
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
    'started_at': status == 'walk_started' ? DateTime.now().toUtc().toIso8601String() : null,
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
