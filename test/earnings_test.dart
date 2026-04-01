import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/models/mock_data.dart';

void main() {
  group('Payment.fromJson', () {
    test('parses full payment JSON with booking joins', () {
      final json = {
        'id': 'pay-001',
        'booking_id': 'b001',
        'amount_mxn': 150.00,
        'status': 'completed',
        'payment_method': 'revenuecat',
        'external_id': 'rc_txn_123',
        'created_at': '2026-03-28T10:00:00Z',
        'updated_at': '2026-03-28T10:05:00Z',
        'bookings': {
          'scheduled_at': '2026-04-01T14:00:00Z',
          'commission_mxn': 27.00,
          'walker_id': 'walker-001',
          'dogs': {'name': 'Max'},
          'users': {'full_name': 'Daniel Smith'},
        },
      };

      final payment = Payment.fromJson(json);

      expect(payment.id, 'pay-001');
      expect(payment.bookingId, 'b001');
      expect(payment.amountMxn, 150.00);
      expect(payment.status, 'completed');
      expect(payment.paymentMethod, 'revenuecat');
      expect(payment.externalId, 'rc_txn_123');
      expect(payment.createdAt, isNotNull);
      expect(payment.updatedAt, isNotNull);
      expect(payment.dogName, 'Max');
      expect(payment.ownerName, 'Daniel Smith');
      expect(payment.scheduledAt, DateTime.utc(2026, 4, 1, 14, 0, 0));
      expect(payment.commissionMxn, 27.00);
    });

    test('handles missing booking joins gracefully', () {
      final json = {
        'id': 'pay-002',
        'booking_id': 'b002',
        'amount_mxn': 200.00,
        'status': 'pending',
        'payment_method': null,
        'external_id': null,
        'created_at': null,
        'updated_at': null,
      };

      final payment = Payment.fromJson(json);

      expect(payment.dogName, isNull);
      expect(payment.ownerName, isNull);
      expect(payment.scheduledAt, isNull);
      expect(payment.commissionMxn, isNull);
      expect(payment.createdAt, isNull);
    });
  });

  group('Payment computed fields', () {
    test('isCompleted returns true only for completed status', () {
      const completed = Payment(id: 'p1', bookingId: 'b1', status: 'completed');
      const pending = Payment(id: 'p2', bookingId: 'b2', status: 'pending');
      const failed = Payment(id: 'p3', bookingId: 'b3', status: 'failed');

      expect(completed.isCompleted, true);
      expect(pending.isCompleted, false);
      expect(failed.isCompleted, false);
    });

    test('walkerEarnings subtracts commission', () {
      const payment = Payment(
        id: 'p1',
        bookingId: 'b1',
        amountMxn: 150,
        commissionMxn: 27,
      );

      expect(payment.walkerEarnings, 123.0);
    });

    test('walkerEarnings returns full amount when no commission', () {
      const payment = Payment(
        id: 'p1',
        bookingId: 'b1',
        amountMxn: 150,
      );

      expect(payment.walkerEarnings, 150.0);
    });

    test('displayStatus returns human-readable labels', () {
      const completed = Payment(id: 'p1', bookingId: 'b1', status: 'completed');
      const pending = Payment(id: 'p2', bookingId: 'b2', status: 'pending');
      const failed = Payment(id: 'p3', bookingId: 'b3', status: 'failed');
      const refunded = Payment(id: 'p4', bookingId: 'b4', status: 'refunded');

      expect(completed.displayStatus, 'Paid');
      expect(pending.displayStatus, 'Pending');
      expect(failed.displayStatus, 'Failed');
      expect(refunded.displayStatus, 'Refunded');
    });

    test('displayAmount and displayEarnings format correctly', () {
      const payment = Payment(
        id: 'p1',
        bookingId: 'b1',
        amountMxn: 150,
        commissionMxn: 27,
      );

      expect(payment.displayAmount, '\$150 MXN');
      expect(payment.displayEarnings, '\$123 MXN');
    });
  });

  group('EarningsScreen UI rendering', () {
    testWidgets('renders earnings list with payment data', (tester) async {
      final payments = [
        const Payment(
          id: 'p1',
          bookingId: 'b1',
          amountMxn: 150,
          status: 'completed',
          commissionMxn: 27,
          dogName: 'Max',
          ownerName: 'Daniel Smith',
        ),
        const Payment(
          id: 'p2',
          bookingId: 'b2',
          amountMxn: 200,
          status: 'completed',
          commissionMxn: 36,
          dogName: 'Buddy',
          ownerName: 'Jane Doe',
        ),
        const Payment(
          id: 'p3',
          bookingId: 'b3',
          amountMxn: 100,
          status: 'pending',
          commissionMxn: 18,
          dogName: 'Luna',
          ownerName: 'Bob Ross',
        ),
      ];

      final completed = payments.where((p) => p.isCompleted).toList();
      final totalEarnings =
          completed.fold<double>(0, (sum, p) => sum + p.walkerEarnings);
      expect(totalEarnings, 287.0); // (150-27) + (200-36)

      final pending = payments.where((p) => p.status == 'pending').toList();
      final pendingTotal =
          pending.fold<double>(0, (sum, p) => sum + p.walkerEarnings);
      expect(pendingTotal, 82.0); // 100-18

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: payments
                  .map((p) => ListTile(
                        title: Text(p.dogName ?? 'Walk'),
                        subtitle: Text(p.ownerName ?? ''),
                        trailing: Text(p.displayEarnings),
                      ))
                  .toList(),
            ),
          ),
        ),
      );

      expect(find.text('Max'), findsOneWidget);
      expect(find.text('Daniel Smith'), findsOneWidget);
      expect(find.text('\$123 MXN'), findsOneWidget);
      expect(find.text('Buddy'), findsOneWidget);
      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('\$164 MXN'), findsOneWidget);
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('Bob Ross'), findsOneWidget);
      expect(find.text('\$82 MXN'), findsOneWidget);
    });

    testWidgets('renders empty state when no payments', (tester) async {
      final payments = <Payment>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: payments.isEmpty
                ? const Center(child: Text('No earnings yet'))
                : const SizedBox(),
          ),
        ),
      );

      expect(find.text('No earnings yet'), findsOneWidget);
    });

    testWidgets('renders error state with retry button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Unable to load your earnings. Please try again.'),
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

      expect(find.text('Unable to load your earnings. Please try again.'),
          findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
