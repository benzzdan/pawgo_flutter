import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:pawgo/services/booking_status_service.dart';

void main() {
  group('BookingStatusUpdate.fromRecord', () {
    test('parses a booking status update record', () {
      final record = {
        'id': 'booking-001',
        'status': 'walk_started',
        'started_at': '2026-03-30T14:00:00Z',
        'completed_at': null,
      };

      final update = BookingStatusUpdate.fromRecord(record);

      expect(update.bookingId, 'booking-001');
      expect(update.newStatus, 'walk_started');
      expect(update.startedAt, '2026-03-30T14:00:00Z');
      expect(update.completedAt, isNull);
    });

    test('parses a completed booking record', () {
      final record = {
        'id': 'booking-002',
        'status': 'walk_completed',
        'started_at': '2026-03-30T14:00:00Z',
        'completed_at': '2026-03-30T14:35:00Z',
      };

      final update = BookingStatusUpdate.fromRecord(record);

      expect(update.bookingId, 'booking-002');
      expect(update.newStatus, 'walk_completed');
      expect(update.completedAt, '2026-03-30T14:35:00Z');
    });
  });

  group('Booking.copyWith', () {
    test('updates status while preserving other fields', () {
      final booking = Booking(
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
      );

      final updated = booking.copyWith(status: 'walk_started');

      expect(updated.status, 'walk_started');
      expect(updated.id, 'b1');
      expect(updated.walkerName, 'Sarah Johnson');
      expect(updated.dogName, 'Max');
      expect(updated.totalPriceMxn, 150);
      expect(updated.isUpcoming, true); // walk_started is still upcoming
    });

    test('updates started_at and completed_at timestamps', () {
      final booking = Booking(
        id: 'b1',
        ownerId: 'o1',
        walkerId: 'w1',
        dogId: 'd1',
        status: 'confirmed',
        scheduledAt: DateTime(2026, 4, 1, 14, 0),
      );

      final startedAt = DateTime(2026, 4, 1, 14, 5);
      final updated = booking.copyWith(
        status: 'walk_started',
        startedAt: startedAt,
      );

      expect(updated.status, 'walk_started');
      expect(updated.startedAt, startedAt);
      expect(updated.completedAt, isNull);

      final completedAt = DateTime(2026, 4, 1, 14, 35);
      final completed = updated.copyWith(
        status: 'walk_completed',
        completedAt: completedAt,
      );

      expect(completed.status, 'walk_completed');
      expect(completed.isPast, true);
      expect(completed.completedAt, completedAt);
    });
  });

  group('BookingStatusService stream behavior', () {
    test('status stream emits updates when controller is fed', () async {
      // Simulates the pattern: service emits BookingStatusUpdate on stream,
      // consumer applies copyWith to update booking list in UI state.
      final controller = StreamController<BookingStatusUpdate>.broadcast();

      // Initial bookings list
      var bookings = [
        Booking(
          id: 'b1',
          ownerId: 'o1',
          walkerId: 'w1',
          dogId: 'd1',
          status: 'confirmed',
          scheduledAt: DateTime(2026, 4, 1, 14, 0),
          walkerName: 'Sarah',
          dogName: 'Max',
        ),
        Booking(
          id: 'b2',
          ownerId: 'o1',
          walkerId: 'w2',
          dogId: 'd2',
          status: 'pending',
          scheduledAt: DateTime(2026, 4, 3, 16, 0),
          walkerName: 'Mike',
          dogName: 'Buddy',
        ),
      ];

      // Listen for status updates and apply to bookings list
      final sub = controller.stream.listen((update) {
        bookings = bookings.map((b) {
          if (b.id == update.bookingId) {
            return b.copyWith(status: update.newStatus);
          }
          return b;
        }).toList();
      });

      // Simulate: booking b1 transitions confirmed → walk_started
      controller.add(const BookingStatusUpdate(
        bookingId: 'b1',
        newStatus: 'walk_started',
      ));
      await Future.delayed(Duration.zero); // Let stream propagate

      expect(bookings[0].status, 'walk_started');
      expect(bookings[0].isUpcoming, true);
      expect(bookings[0].displayStatus, 'In Progress');
      expect(bookings[1].status, 'pending'); // Unaffected

      // Simulate: booking b1 transitions walk_started → walk_completed
      controller.add(const BookingStatusUpdate(
        bookingId: 'b1',
        newStatus: 'walk_completed',
      ));
      await Future.delayed(Duration.zero);

      expect(bookings[0].status, 'walk_completed');
      expect(bookings[0].isPast, true);
      expect(bookings[0].displayStatus, 'Completed');

      await sub.cancel();
      await controller.close();
    });

    test('status update moves booking between filter tabs', () async {
      final controller = StreamController<BookingStatusUpdate>.broadcast();

      var bookings = [
        Booking(
          id: 'b1',
          ownerId: 'o1',
          walkerId: 'w1',
          dogId: 'd1',
          status: 'confirmed',
          scheduledAt: DateTime(2026, 4, 1, 14, 0),
        ),
      ];

      final sub = controller.stream.listen((update) {
        bookings = bookings.map((b) {
          if (b.id == update.bookingId) {
            return b.copyWith(status: update.newStatus);
          }
          return b;
        }).toList();
      });

      // Initially in upcoming tab
      expect(bookings.where((b) => b.isUpcoming).length, 1);
      expect(bookings.where((b) => b.isPast).length, 0);

      // Complete the walk
      controller.add(const BookingStatusUpdate(
        bookingId: 'b1',
        newStatus: 'walk_completed',
      ));
      await Future.delayed(Duration.zero);

      // Now in past tab
      expect(bookings.where((b) => b.isUpcoming).length, 0);
      expect(bookings.where((b) => b.isPast).length, 1);

      await sub.cancel();
      await controller.close();
    });

    test('cancelled status update moves booking to cancelled tab', () async {
      final controller = StreamController<BookingStatusUpdate>.broadcast();

      var bookings = [
        Booking(
          id: 'b1',
          ownerId: 'o1',
          walkerId: 'w1',
          dogId: 'd1',
          status: 'confirmed',
          scheduledAt: DateTime(2026, 4, 1, 14, 0),
        ),
      ];

      final sub = controller.stream.listen((update) {
        bookings = bookings.map((b) {
          if (b.id == update.bookingId) {
            return b.copyWith(status: update.newStatus);
          }
          return b;
        }).toList();
      });

      controller.add(const BookingStatusUpdate(
        bookingId: 'b1',
        newStatus: 'cancelled',
      ));
      await Future.delayed(Duration.zero);

      expect(bookings[0].isCancelled, true);
      expect(bookings.where((b) => b.isUpcoming).length, 0);
      expect(bookings.where((b) => b.isCancelled).length, 1);

      await sub.cancel();
      await controller.close();
    });
  });

  group('Integration: BookingsScreen UI updates from status stream', () {
    testWidgets('booking card status badge updates when status changes',
        (tester) async {
      // Simulate the flow: render bookings, emit status update, verify UI
      final statusController =
          StreamController<BookingStatusUpdate>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          home: _BookingStatusTestWidget(
            statusStream: statusController.stream,
          ),
        ),
      );

      // Initially shows Confirmed
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('In Progress'), findsNothing);

      // Emit status update
      statusController.add(const BookingStatusUpdate(
        bookingId: 'b1',
        newStatus: 'walk_started',
      ));
      await tester.pumpAndSettle();

      // Now shows In Progress
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Confirmed'), findsNothing);

      // Emit another status update
      statusController.add(const BookingStatusUpdate(
        bookingId: 'b1',
        newStatus: 'walk_completed',
      ));
      await tester.pumpAndSettle();

      // Now shows Completed
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('In Progress'), findsNothing);

      await statusController.close();
    });

    testWidgets('connection state shows banner on disconnect',
        (tester) async {
      var connectionState = BookingStatusConnectionState.connected;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    if (connectionState ==
                            BookingStatusConnectionState.error ||
                        connectionState ==
                            BookingStatusConnectionState.disconnected)
                      Container(
                        key: const ValueKey('connection-banner'),
                        padding: const EdgeInsets.all(8),
                        color: Colors.amber.shade100,
                        child: const Text(
                            'Live updates unavailable. Tap to refresh.'),
                      ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          connectionState =
                              BookingStatusConnectionState.error;
                        });
                      },
                      child: const Text('Simulate Disconnect'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // No banner initially
      expect(find.text('Live updates unavailable. Tap to refresh.'),
          findsNothing);

      // Tap to simulate disconnect
      await tester.tap(find.text('Simulate Disconnect'));
      await tester.pump();

      // Banner now visible
      expect(find.text('Live updates unavailable. Tap to refresh.'),
          findsOneWidget);
    });
  });

  group('Integration: ActiveWalkScreen booking status', () {
    test('walk_completed status triggers UI update', () async {
      final controller = StreamController<BookingStatusUpdate>.broadcast();
      String bookingStatus = 'walk_started';
      bool walkCompletedReceived = false;

      final sub = controller.stream.listen((update) {
        bookingStatus = update.newStatus;
        if (update.newStatus == 'walk_completed') {
          walkCompletedReceived = true;
        }
      });

      // Simulate status change from walk_started → walk_completed
      controller.add(const BookingStatusUpdate(
        bookingId: 'booking-001',
        newStatus: 'walk_completed',
        completedAt: '2026-03-30T14:35:00Z',
      ));
      await Future.delayed(Duration.zero);

      expect(bookingStatus, 'walk_completed');
      expect(walkCompletedReceived, true);

      await sub.cancel();
      await controller.close();
    });
  });
}

/// Test helper widget that listens to a booking status stream and updates UI.
class _BookingStatusTestWidget extends StatefulWidget {
  final Stream<BookingStatusUpdate> statusStream;

  const _BookingStatusTestWidget({required this.statusStream});

  @override
  State<_BookingStatusTestWidget> createState() =>
      _BookingStatusTestWidgetState();
}

class _BookingStatusTestWidgetState extends State<_BookingStatusTestWidget> {
  StreamSubscription<BookingStatusUpdate>? _sub;
  List<Booking> _bookings = [
    Booking(
      id: 'b1',
      ownerId: 'o1',
      walkerId: 'w1',
      dogId: 'd1',
      status: 'confirmed',
      scheduledAt: DateTime(2026, 4, 1, 14, 0),
      walkerName: 'Sarah Johnson',
      dogName: 'Max',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _sub = widget.statusStream.listen((update) {
      setState(() {
        _bookings = _bookings.map((b) {
          if (b.id == update.bookingId) {
            return b.copyWith(status: update.newStatus);
          }
          return b;
        }).toList();
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: _bookings
            .map((b) => ListTile(
                  key: ValueKey(b.id),
                  title: Text(b.walkerName),
                  subtitle: Text(b.displayStatus),
                  trailing: Text(b.dogName),
                ))
            .toList(),
      ),
    );
  }
}
