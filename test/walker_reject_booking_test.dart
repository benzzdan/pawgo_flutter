import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/screens/walk_request_screen.dart';

// ---------------------------------------------------------------------------
// Tests for US-004: Walker reject pending booking
// ---------------------------------------------------------------------------

void main() {
  group('US-004: Walker reject pending booking', () {
    group('Reject button visibility and styling', () {
      testWidgets('shows Reject button on pending booking detail',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(booking: _testBooking()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Reject'), findsOneWidget);
      });

      testWidgets('shows both Accept and Reject buttons', (tester) async {
        await tester.pumpWidget(
          _buildTestApp(booking: _testBooking()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Accept'), findsOneWidget);
        expect(find.text('Reject'), findsOneWidget);
      });

      testWidgets('Reject button is styled as outlined destructive',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(booking: _testBooking()),
        );
        await tester.pumpAndSettle();

        // Find the Reject button — should be an OutlinedButton
        final rejectButton = find.ancestor(
          of: find.text('Reject'),
          matching: find.byType(OutlinedButton),
        );
        expect(rejectButton, findsOneWidget);
      });
    });

    group('Confirmation dialog', () {
      testWidgets(
          'shows confirmation dialog when Reject is tapped',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(booking: _testBooking()),
        );
        await tester.pumpAndSettle();

        // Scroll Reject into view and tap
        await tester.ensureVisible(find.text('Reject'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reject'));
        await tester.pumpAndSettle();

        expect(find.text('Reject this booking request?'), findsOneWidget);
      });

      testWidgets('dismisses dialog when Cancel is tapped', (tester) async {
        await tester.pumpWidget(
          _buildTestApp(booking: _testBooking()),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Reject'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reject'));
        await tester.pumpAndSettle();

        // Tap Cancel to dismiss
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Reject this booking request?'), findsNothing);
      });
    });

    group('No Reject button when expired', () {
      testWidgets('hides Reject button when booking is expired',
          (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            booking: _testBooking(
              deadlineFromNow: const Duration(seconds: -10),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Reject'), findsNothing);
      });
    });
  });
}

// --- Test helpers ---

Map<String, dynamic> _testBooking({
  Duration deadlineFromNow = const Duration(minutes: 5),
}) {
  return {
    'id': 'test-booking-1',
    'status': 'pending_walker_acceptance',
    'scheduled_at': '2026-04-15T14:00:00Z',
    'duration_minutes': 30,
    'hourly_rate_mxn': 200,
    'total_price_mxn': 100,
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
      'hourly_rate_mxn': 200,
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
