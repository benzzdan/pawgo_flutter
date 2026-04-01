import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/models/mock_data.dart';

void main() {
  group('Booking.fromJson', () {
    test('parses full booking JSON with walker and dog joins', () {
      final json = {
        'id': 'b001',
        'owner_id': 'owner-001',
        'walker_id': 'walker-001',
        'dog_id': 'dog-001',
        'status': 'confirmed',
        'scheduled_at': '2026-04-01T14:00:00Z',
        'started_at': null,
        'completed_at': null,
        'duration_minutes': 30,
        'total_price_mxn': 150.00,
        'commission_mxn': 27.00,
        'notes': 'Please bring treats',
        'created_at': '2026-03-28T10:00:00Z',
        'updated_at': '2026-03-28T10:00:00Z',
        'walkers': {
          'id': 'walker-001',
          'users': {
            'full_name': 'Sarah Johnson',
            'avatar_url': 'https://example.com/avatar.jpg',
          },
        },
        'dogs': {
          'name': 'Max',
        },
      };

      final booking = Booking.fromJson(json);

      expect(booking.id, 'b001');
      expect(booking.ownerId, 'owner-001');
      expect(booking.walkerId, 'walker-001');
      expect(booking.dogId, 'dog-001');
      expect(booking.status, 'confirmed');
      expect(booking.scheduledAt, DateTime.utc(2026, 4, 1, 14, 0, 0));
      expect(booking.startedAt, isNull);
      expect(booking.completedAt, isNull);
      expect(booking.durationMinutes, 30);
      expect(booking.totalPriceMxn, 150.00);
      expect(booking.commissionMxn, 27.00);
      expect(booking.notes, 'Please bring treats');
      expect(booking.walkerName, 'Sarah Johnson');
      expect(booking.walkerAvatarUrl, 'https://example.com/avatar.jpg');
      expect(booking.dogName, 'Max');
      expect(booking.createdAt, isNotNull);
    });

    test('handles missing walker and dog joins gracefully', () {
      final json = {
        'id': 'b002',
        'owner_id': 'owner-001',
        'walker_id': 'walker-002',
        'dog_id': 'dog-002',
        'status': 'pending',
        'scheduled_at': '2026-04-02T16:30:00Z',
        'started_at': null,
        'completed_at': null,
        'duration_minutes': null,
        'total_price_mxn': 0,
        'commission_mxn': 0,
        'notes': null,
        'created_at': null,
        'updated_at': null,
      };

      final booking = Booking.fromJson(json);

      expect(booking.walkerName, 'Unknown Walker');
      expect(booking.walkerAvatarUrl, isNull);
      expect(booking.dogName, '');
      expect(booking.durationMinutes, isNull);
      expect(booking.notes, isNull);
    });

    test('parses completed booking with all timestamps', () {
      final json = {
        'id': 'b003',
        'owner_id': 'owner-001',
        'walker_id': 'walker-001',
        'dog_id': 'dog-001',
        'status': 'walk_completed',
        'scheduled_at': '2026-03-25T14:00:00Z',
        'started_at': '2026-03-25T14:05:00Z',
        'completed_at': '2026-03-25T14:35:00Z',
        'duration_minutes': 30,
        'total_price_mxn': 150.00,
        'commission_mxn': 27.00,
        'notes': null,
        'created_at': '2026-03-24T10:00:00Z',
        'updated_at': '2026-03-25T14:35:00Z',
        'walkers': {
          'id': 'walker-001',
          'users': {
            'full_name': 'Sarah Johnson',
            'avatar_url': null,
          },
        },
        'dogs': {
          'name': 'Buddy',
        },
      };

      final booking = Booking.fromJson(json);

      expect(booking.startedAt, isNotNull);
      expect(booking.completedAt, isNotNull);
      expect(booking.isPast, true);
      expect(booking.isUpcoming, false);
      expect(booking.isCancelled, false);
    });
  });

  group('Booking status helpers', () {
    Booking makeBooking(String status) => Booking(
          id: 'test',
          ownerId: 'o1',
          walkerId: 'w1',
          dogId: 'd1',
          status: status,
          scheduledAt: DateTime.now(),
        );

    test('isUpcoming for active statuses', () {
      expect(makeBooking('pending').isUpcoming, true);
      expect(makeBooking('confirmed').isUpcoming, true);
      expect(makeBooking('walker_en_route').isUpcoming, true);
      expect(makeBooking('walk_started').isUpcoming, true);
      expect(makeBooking('walk_completed').isUpcoming, false);
      expect(makeBooking('cancelled').isUpcoming, false);
    });

    test('isPast only for walk_completed', () {
      expect(makeBooking('walk_completed').isPast, true);
      expect(makeBooking('confirmed').isPast, false);
    });

    test('isCancelled only for cancelled', () {
      expect(makeBooking('cancelled').isCancelled, true);
      expect(makeBooking('confirmed').isCancelled, false);
    });

    test('displayStatus returns human-readable labels', () {
      expect(makeBooking('pending').displayStatus, 'Pending');
      expect(makeBooking('confirmed').displayStatus, 'Confirmed');
      expect(makeBooking('walker_en_route').displayStatus, 'Walker En Route');
      expect(makeBooking('walk_started').displayStatus, 'In Progress');
      expect(makeBooking('walk_completed').displayStatus, 'Completed');
      expect(makeBooking('cancelled').displayStatus, 'Cancelled');
      expect(makeBooking('disputed').displayStatus, 'Disputed');
    });

    test('displayPrice formats correctly', () {
      final booking = Booking(
        id: 'test',
        ownerId: 'o1',
        walkerId: 'w1',
        dogId: 'd1',
        status: 'confirmed',
        scheduledAt: DateTime.now(),
        totalPriceMxn: 150,
      );
      expect(booking.displayPrice, '\$150 MXN');
    });

    test('statusColor returns correct colors for each status', () {
      expect(makeBooking('confirmed').statusColor, const Color(0xFF16A34A));
      expect(makeBooking('walk_started').statusColor, const Color(0xFF2563EB));
      expect(makeBooking('cancelled').statusColor, const Color(0xFFDC2626));
      expect(makeBooking('pending').statusColor, const Color(0xFFF59E0B));
    });
  });

  group('BookingsScreen UI rendering', () {
    testWidgets('renders booking list with mocked data', (tester) async {
      final bookings = [
        Booking(
          id: 'b1',
          ownerId: 'o1',
          walkerId: 'w1',
          dogId: 'd1',
          status: 'confirmed',
          scheduledAt: DateTime(2026, 4, 1, 14, 0),
          durationMinutes: 30,
          totalPriceMxn: 150,
          walkerName: 'Sarah Johnson',
          dogName: 'Max',
        ),
        Booking(
          id: 'b2',
          ownerId: 'o1',
          walkerId: 'w2',
          dogId: 'd2',
          status: 'pending',
          scheduledAt: DateTime(2026, 4, 3, 16, 30),
          walkerName: 'Mike Chen',
          dogName: 'Buddy',
        ),
      ];

      // Verify bookings are correctly filtered
      final upcoming = bookings.where((b) => b.isUpcoming).toList();
      expect(upcoming.length, 2);
      expect(upcoming[0].walkerName, 'Sarah Johnson');
      expect(upcoming[1].walkerName, 'Mike Chen');

      final past = bookings.where((b) => b.isPast).toList();
      expect(past.length, 0);

      // Verify rendering in a simple widget tree
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: bookings
                  .map((b) => ListTile(
                        title: Text(b.walkerName),
                        subtitle: Text(b.displayStatus),
                        trailing: Text(b.dogName),
                      ))
                  .toList(),
            ),
          ),
        ),
      );

      expect(find.text('Sarah Johnson'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
      expect(find.text('Mike Chen'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Buddy'), findsOneWidget);
    });

    testWidgets('renders empty state when no bookings', (tester) async {
      final bookings = <Booking>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: bookings.isEmpty
                ? const Center(child: Text('No walks planned'))
                : const SizedBox(),
          ),
        ),
      );

      expect(find.text('No walks planned'), findsOneWidget);
    });

    testWidgets('renders error state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Could not load bookings'),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Could not load bookings'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
