import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/services/booking_status_service.dart';
import 'package:pawgo/utils/walk_request_cancellation.dart';

void main() {
  group('shouldAutoExitOnCancellation', () {
    test('returns true when status is cancelled and isWalker is true and not already cancelled', () {
      expect(
        shouldAutoExitOnCancellation(
          newStatus: 'cancelled',
          isWalkerScreen: true,
          alreadyCancelled: false,
        ),
        isTrue,
      );
    });

    test('returns false when status is cancelled but not walker screen', () {
      expect(
        shouldAutoExitOnCancellation(
          newStatus: 'cancelled',
          isWalkerScreen: false,
          alreadyCancelled: false,
        ),
        isFalse,
      );
    });

    test('returns false when status is not cancelled', () {
      expect(
        shouldAutoExitOnCancellation(
          newStatus: 'confirmed',
          isWalkerScreen: true,
          alreadyCancelled: false,
        ),
        isFalse,
      );
    });

    test('returns false when already cancelled (prevents duplicate navigation)', () {
      expect(
        shouldAutoExitOnCancellation(
          newStatus: 'cancelled',
          isWalkerScreen: true,
          alreadyCancelled: true,
        ),
        isFalse,
      );
    });

    test('returns false for pending_walker_acceptance status', () {
      expect(
        shouldAutoExitOnCancellation(
          newStatus: 'pending_walker_acceptance',
          isWalkerScreen: true,
          alreadyCancelled: false,
        ),
        isFalse,
      );
    });
  });

  group('WalkRequestScreen cancellation via status stream', () {
    testWidgets('shows cancellation banner and pops when status changes to cancelled', (tester) async {
      final statusController = StreamController<BookingStatusUpdate>.broadcast();
      bool didPop = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: const Text('My Walks')),
          routes: {
            '/walk-request-cancel-test': (context) =>
                _CancellationTestWidget(
                  statusStream: statusController.stream,
                  onPop: () => didPop = true,
                ),
          },
        ),
      );

      // Navigate to the walk request screen
      final navState = tester.state<NavigatorState>(find.byType(Navigator));
      navState.pushNamed('/walk-request-cancel-test');
      await tester.pumpAndSettle();

      expect(find.text('Walk Request Detail'), findsOneWidget);

      // Emit cancellation
      statusController.add(const BookingStatusUpdate(
        bookingId: 'b1',
        newStatus: 'cancelled',
      ));
      // Let stream deliver + SnackBar animate in
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Banner should appear
      expect(find.text('The owner canceled this walk request'), findsOneWidget);

      // Wait for the pop delay (3 seconds from event)
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Should have popped
      expect(didPop, isTrue);

      await statusController.close();
    });

    testWidgets('does not pop twice on duplicate cancellation events', (tester) async {
      final statusController = StreamController<BookingStatusUpdate>.broadcast();
      int popCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: const Text('My Walks')),
          routes: {
            '/walk-request-cancel-test': (context) =>
                _CancellationTestWidget(
                  statusStream: statusController.stream,
                  onPop: () => popCount++,
                ),
          },
        ),
      );

      final navState = tester.state<NavigatorState>(find.byType(Navigator));
      navState.pushNamed('/walk-request-cancel-test');
      await tester.pumpAndSettle();

      // Emit two cancellation events rapidly
      statusController.add(const BookingStatusUpdate(
        bookingId: 'b1',
        newStatus: 'cancelled',
      ));
      statusController.add(const BookingStatusUpdate(
        bookingId: 'b1',
        newStatus: 'cancelled',
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Should only pop once
      expect(popCount, 1);

      await statusController.close();
    });
  });
}

/// Test helper widget simulating the walk request screen's cancellation behavior.
class _CancellationTestWidget extends StatefulWidget {
  final Stream<BookingStatusUpdate> statusStream;
  final VoidCallback onPop;

  const _CancellationTestWidget({
    required this.statusStream,
    required this.onPop,
  });

  @override
  State<_CancellationTestWidget> createState() => _CancellationTestWidgetState();
}

class _CancellationTestWidgetState extends State<_CancellationTestWidget> {
  StreamSubscription<BookingStatusUpdate>? _sub;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.statusStream.listen(_onStatusUpdate);
  }

  void _onStatusUpdate(BookingStatusUpdate update) {
    if (!mounted) return;
    if (shouldAutoExitOnCancellation(
      newStatus: update.newStatus,
      isWalkerScreen: true,
      alreadyCancelled: _cancelled,
    )) {
      _cancelled = true;
      // Show banner
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The owner canceled this walk request'),
          duration: Duration(seconds: 3),
        ),
      );
      // Pop after delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          widget.onPop();
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Walk Request Detail')),
      body: const Center(child: Text('Walk request details here')),
    );
  }
}
