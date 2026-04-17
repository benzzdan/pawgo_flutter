import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/services/notification_service.dart';
import 'package:pawgo/screens/walk_request_screen.dart';

void main() {
  group('US-012: Walk request screen', () {
    // --- NotificationRouter tests (pure logic) ---
    group('NotificationRouter: walk_request type routing', () {
      test('maps walk_request to /walk-request with booking_id in arguments',
          () {
        final nav = NotificationRouter.routeFor(
          type: 'walk_request',
          bookingId: 'booking-walk-req-1',
        );
        expect(nav, isNotNull);
        expect(nav!.route, '/walk-request');
        expect(nav.arguments?['booking_id'], 'booking-walk-req-1');
      });

      test('walk_request route has no tab set', () {
        final nav = NotificationRouter.routeFor(
          type: 'walk_request',
          bookingId: 'booking-walk-req-2',
        );
        expect(nav, isNotNull);
        expect(nav!.tab, isNull);
      });
    });

    // --- Walk request screen widget tests ---
    group('WalkRequestScreen: displays booking details', () {
      testWidgets('shows owner name, dog name, and pickup location',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(booking: _testBooking()),
        );

        await tester.pumpAndSettle();

        // Should display owner name
        expect(find.text('Maria Garcia'), findsOneWidget);
        // Should display dog name
        expect(find.text('Max'), findsOneWidget);
        // Should display pickup location
        expect(find.textContaining('Parque Lincoln'), findsOneWidget);
      });

      testWidgets(
          'shows estimated earnings calculated from hourly rate and duration',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            booking: _testBooking(hourlyRate: 200, durationMinutes: 30),
          ),
        );

        await tester.pumpAndSettle();

        // 200 MXN/hr * 30min/60 = 100 MXN estimated earnings
        expect(find.textContaining('\$100 MXN'), findsOneWidget);
      });

      testWidgets('shows countdown timer with time remaining',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            booking: _testBooking(
              deadlineFromNow: const Duration(minutes: 3, seconds: 30),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show time remaining text
        expect(find.textContaining('Time remaining'), findsOneWidget);
      });

      testWidgets('shows dog breed', (tester) async {
        await tester.pumpWidget(
          _buildTestApp(booking: _testBooking()),
        );

        await tester.pumpAndSettle();

        expect(find.text('Golden Retriever'), findsOneWidget);
      });

      testWidgets('shows scheduled date', (tester) async {
        await tester.pumpWidget(
          _buildTestApp(booking: _testBooking()),
        );

        await tester.pumpAndSettle();

        // The formatted date for 2026-04-15T14:00:00Z
        expect(find.textContaining('Apr'), findsOneWidget);
        expect(find.textContaining('15'), findsWidgets);
      });

      testWidgets('shows duration', (tester) async {
        await tester.pumpWidget(
          _buildTestApp(booking: _testBooking(durationMinutes: 45)),
        );

        await tester.pumpAndSettle();

        expect(find.textContaining('45 min'), findsOneWidget);
      });
    });

    group('WalkRequestScreen: accept and decline actions', () {
      testWidgets('has Accept and Decline buttons', (tester) async {
        await tester.pumpWidget(
          _buildTestApp(booking: _testBooking()),
        );

        await tester.pumpAndSettle();

        expect(find.text('Accept'), findsOneWidget);
        expect(find.text('Decline'), findsOneWidget);
      });

      testWidgets('shows confirmation dialog when decline is tapped',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(booking: _testBooking()),
        );

        await tester.pumpAndSettle();

        // Scroll the Decline button into view before tapping
        await tester.ensureVisible(find.text('Decline'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Decline'));
        await tester.pumpAndSettle();

        // Should show a confirmation dialog with decline-related text
        expect(find.text('Decline Request?'), findsOneWidget);
        expect(find.textContaining('Are you sure'), findsOneWidget);
      });
    });

    group('WalkRequestScreen: expired booking', () {
      testWidgets('shows expired message when deadline has passed',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            booking: _testBooking(
              deadlineFromNow: const Duration(seconds: -10),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show expired message
        expect(find.textContaining('expired'), findsWidgets);
      });

      testWidgets('does not show Accept/Decline buttons when expired',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            booking: _testBooking(
              deadlineFromNow: const Duration(seconds: -10),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Accept'), findsNothing);
        expect(find.text('Decline'), findsNothing);
      });

      testWidgets('shows Go Back button when expired', (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            booking: _testBooking(
              deadlineFromNow: const Duration(seconds: -10),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Go Back'), findsOneWidget);
      });
    });

    group('WalkRequestScreen: error state', () {
      testWidgets('shows error when no booking ID provided', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const WalkRequestScreen(),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.textContaining('No booking ID'), findsOneWidget);
      });
    });
  });
}

// --- Test helpers ---

Map<String, dynamic> _testBooking({
  double hourlyRate = 200,
  int durationMinutes = 30,
  Duration deadlineFromNow = const Duration(minutes: 5),
}) {
  return {
    'id': 'test-booking-1',
    'status': 'pending_walker_acceptance',
    'scheduled_at': '2026-04-15T14:00:00Z',
    'duration_minutes': durationMinutes,
    'hourly_rate_mxn': hourlyRate,
    'total_price_mxn': (hourlyRate * durationMinutes / 60).round(),
    'pickup_location': 'Parque Lincoln, Polanco',
    'acceptance_deadline': DateTime.now()
        .toUtc()
        .add(deadlineFromNow)
        .toIso8601String(),
    'dogs': {
      'name': 'Max',
      'breed': 'Golden Retriever',
      'photo_url': null,
    },
    'users': {
      'full_name': 'Maria Garcia',
      'avatar_url': null,
    },
    'walkers': {
      'user_id': 'test-walker-user-id',
      'hourly_rate_mxn': hourlyRate,
    },
  };
}

Widget _buildTestApp({required Map<String, dynamic> booking}) {
  return MaterialApp(
    initialRoute: '/walk-request',
    onGenerateRoute: (settings) {
      if (settings.name == '/walk-request') {
        return MaterialPageRoute(
          settings: RouteSettings(
            name: '/walk-request',
            arguments: {
              'booking_id': booking['id'],
              '_test_booking': booking,
            },
          ),
          builder: (context) => const WalkRequestScreen(),
        );
      }
      if (settings.name == '/walker-bookings' || settings.name == '/home') {
        return MaterialPageRoute(
          builder: (context) => const Scaffold(body: Text('navigated')),
        );
      }
      return null;
    },
  );
}
