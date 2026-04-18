import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/screens/bookings_screen.dart';
import 'package:pawgo/services/booking_status_service.dart';

// ---------------------------------------------------------------------------
// Tests for US-003: Owner cancel booking
// ---------------------------------------------------------------------------

void main() {
  // Ensure the dummy SupabaseClient's realtime is disconnected before tests run,
  // to prevent heartbeat timers from leaking.
  setUpAll(() {
    _StubBookingStatusService._dummyClient.realtime.disconnect();
  });

  group('US-003: Owner cancel booking', () {
    group('Cancel Booking button visibility in detail sheet', () {
      testWidgets('shows Cancel Booking button for pending status',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(bookings: [_testBooking(status: 'pending')]),
        );
        await tester.pumpAndSettle();

        // Tap card to open detail sheet
        await tester.tap(find.text('Test Walker'));
        await tester.pumpAndSettle();

        expect(find.text('Cancel Booking'), findsOneWidget);
      });

      testWidgets('shows Cancel Booking button for confirmed status',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(bookings: [_testBooking(status: 'confirmed')]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Test Walker'));
        await tester.pumpAndSettle();

        expect(find.text('Cancel Booking'), findsOneWidget);
      });

      testWidgets('hides Cancel Booking for walk_completed status',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            bookings: [_testBooking(status: 'walk_completed')],
            initialTab: 'past',
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Test Walker'));
        await tester.pumpAndSettle();

        expect(find.text('Cancel Booking'), findsNothing);
      });

      testWidgets('hides Cancel Booking for cancelled_by_owner status',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            bookings: [_testBooking(status: 'cancelled_by_owner')],
            initialTab: 'cancelled',
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Test Walker'));
        await tester.pumpAndSettle();

        expect(find.text('Cancel Booking'), findsNothing);
      });

      testWidgets('hides Cancel Booking for cancelled_by_walker status',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            bookings: [_testBooking(status: 'cancelled_by_walker')],
            initialTab: 'cancelled',
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Test Walker'));
        await tester.pumpAndSettle();

        expect(find.text('Cancel Booking'), findsNothing);
      });

      testWidgets('hides Cancel Booking for rejected_by_walker status',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            bookings: [_testBooking(status: 'rejected_by_walker')],
            initialTab: 'cancelled',
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Test Walker'));
        await tester.pumpAndSettle();

        expect(find.text('Cancel Booking'), findsNothing);
      });
    });

    group('Confirmation dialog', () {
      testWidgets(
          'shows confirmation dialog with correct text on Cancel Booking tap',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(bookings: [_testBooking(status: 'pending')]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Test Walker'));
        await tester.pumpAndSettle();

        // Scroll into view and tap
        await tester.ensureVisible(find.text('Cancel Booking'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel Booking'));
        await tester.pumpAndSettle();

        expect(find.text('Cancel Booking?'), findsOneWidget);
        expect(
          find.text(
              'Are you sure you want to cancel? This cannot be undone.'),
          findsOneWidget,
        );
      });

      testWidgets('dismisses dialog without action when Keep is tapped',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(bookings: [_testBooking(status: 'confirmed')]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Test Walker'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Cancel Booking'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel Booking'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Keep'));
        await tester.pumpAndSettle();

        // Dialog dismissed, detail sheet still visible
        expect(find.text('Cancel Booking?'), findsNothing);
      });
    });

    group('Cancelled tab includes new statuses', () {
      testWidgets('cancelled_by_owner bookings appear in Cancelled tab',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            bookings: [_testBooking(status: 'cancelled_by_owner')],
            initialTab: 'cancelled',
          ),
        );
        await tester.pumpAndSettle();

        // Should show the booking card
        expect(find.text('Test Walker'), findsOneWidget);
      });

      testWidgets('cancelled_by_walker bookings appear in Cancelled tab',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            bookings: [_testBooking(status: 'cancelled_by_walker')],
            initialTab: 'cancelled',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Test Walker'), findsOneWidget);
      });

      testWidgets('rejected_by_walker bookings appear in Cancelled tab',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            bookings: [_testBooking(status: 'rejected_by_walker')],
            initialTab: 'cancelled',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Test Walker'), findsOneWidget);
      });
    });

    group('Status badges for new statuses', () {
      testWidgets('cancelled_by_owner shows Cancelled by You badge',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            bookings: [_testBooking(status: 'cancelled_by_owner')],
            initialTab: 'cancelled',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cancelled by You'), findsOneWidget);
      });

      testWidgets('cancelled_by_walker shows Cancelled by Walker badge',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            bookings: [_testBooking(status: 'cancelled_by_walker')],
            initialTab: 'cancelled',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cancelled by Walker'), findsOneWidget);
      });

      testWidgets('rejected_by_walker shows Rejected badge',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            bookings: [_testBooking(status: 'rejected_by_walker')],
            initialTab: 'cancelled',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Rejected'), findsOneWidget);
      });
    });
  });
}

// --- Test Helpers ---

Map<String, dynamic> _testBooking({
  String status = 'pending',
  String id = 'test-booking-1',
}) {
  return {
    'id': id,
    'status': status,
    'scheduled_at': '2026-04-20T14:00:00Z',
    'duration_minutes': 60,
    'total_price_mxn': 200,
    'notes': null,
    'started_at': status == 'walk_started' || status == 'walk_completed'
        ? '2026-04-20T14:00:00Z'
        : null,
    'completed_at':
        status == 'walk_completed' ? '2026-04-20T15:00:00Z' : null,
    'owner_id': 'test-owner-id',
    'walker_id': 'test-walker-id',
    'acceptance_deadline': null,
    'walkers': {
      'id': 'test-walker-id',
      'user_id': 'test-walker-user-id',
      'users': {
        'full_name': 'Test Walker',
        'avatar_url': null,
      },
    },
    'dogs': {
      'name': 'Buddy',
      'breed': 'Labrador',
      'photo_url': null,
    },
  };
}

/// A no-op BookingStatusService for testing.
/// We pass a dummy SupabaseClient to avoid the Supabase.instance assertion.
class _StubBookingStatusService extends BookingStatusService {
  _StubBookingStatusService() : super(client: _dummyClient);

  static final _dummyClient = SupabaseClient(
    'https://localhost',
    'fake-anon-key',
  );

  final _testConnectionController =
      StreamController<BookingStatusConnectionState>.broadcast();

  @override
  Stream<BookingStatusConnectionState> get connectionStream =>
      _testConnectionController.stream;

  @override
  void subscribe({required String filterColumn, required String filterValue}) {}

  @override
  void dispose() {
    _testConnectionController.close();
    super.dispose();
    // Dispose the realtime connection to prevent timer leaks
    _dummyClient.realtime.disconnect();
  }
}

Widget _buildTestApp({
  required List<Map<String, dynamic>> bookings,
  String initialTab = 'upcoming',
}) {
  BookingsScreen.pendingInitialTab = initialTab;
  return MaterialApp(
    home: Scaffold(
      body: BookingsScreen(
        bookingStatusService: _StubBookingStatusService(),
        testBookings: bookings,
      ),
    ),
    routes: {
      '/active-walk': (_) => const Scaffold(body: Text('active walk')),
      '/chat': (_) => const Scaffold(body: Text('chat')),
      '/insurance-claim': (_) => const Scaffold(body: Text('insurance')),
    },
  );
}
