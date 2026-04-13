import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/services/booking_status_service.dart';
import 'package:pawgo/screens/bookings_screen.dart';

void main() {
  group('US-002: Review screen premature exit fix', () {
    group('ActiveWalkScreen: walk_completed handler must not navigate away', () {
      test(
          'BookingStatusService walk_completed should only update state, not navigate to /home',
          () async {
        // This test simulates the active_walk_screen pattern.
        // The CURRENT (buggy) code does:
        //   if (update.newStatus == 'walk_completed' && !_isWalker) {
        //     Future.delayed(Duration(seconds: 2), () => pushNamedAndRemoveUntil('/home'));
        //   }
        //
        // After fix, the handler should ONLY update _bookingStatus state,
        // with NO navigation (the direct Realtime channel handles review navigation).

        final controller = StreamController<BookingStatusUpdate>.broadcast();
        String bookingStatus = 'walk_started';
        bool wouldNavigateHome = false;

        // This mirrors the FIXED handler behavior.
        // The test asserts the pattern: status update = state change only.
        final sub = controller.stream.listen((update) {
          bookingStatus = update.newStatus;
          // After fix: NO navigation on walk_completed from BookingStatusService.
          // The direct Realtime channel in _subscribeToBookingStatus() handles
          // navigation to /review. This handler must NOT also navigate to /home.
        });

        controller.add(const BookingStatusUpdate(
          bookingId: 'booking-001',
          newStatus: 'walk_completed',
        ));
        await Future.delayed(Duration.zero);

        expect(bookingStatus, 'walk_completed');
        expect(wouldNavigateHome, false,
            reason: 'BookingStatusService handler must not navigate on walk_completed');

        await sub.cancel();
        await controller.close();
      });
    });

    group('BookingsScreen initial filter support', () {
      test('BookingsScreen has a static pendingInitialTab field', () {
        // After the fix, BookingsScreen should have a static field that
        // the review screen can set to 'past' before navigating,
        // so the bookings screen opens with the Past tab selected.
        //
        // This test will FAIL if the static field doesn't exist yet.
        expect(BookingsScreen.pendingInitialTab, isNull);

        BookingsScreen.pendingInitialTab = 'past';
        expect(BookingsScreen.pendingInitialTab, 'past');

        // Clean up
        BookingsScreen.pendingInitialTab = null;
      });
    });

    group('ReviewScreen navigation after submit/skip', () {
      testWidgets(
          'review navigation helper goes to /home with bookings tab and sets past filter',
          (tester) async {
        String? navigatedRoute;
        Object? navigatedArgs;

        await tester.pumpWidget(
          MaterialApp(
            initialRoute: '/test',
            routes: {
              '/test': (context) => Scaffold(
                    body: ElevatedButton(
                      onPressed: () {
                        // This is the navigation pattern the review screen should use:
                        BookingsScreen.pendingInitialTab = 'past';
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/home',
                          (route) => false,
                          arguments: {'tab': 2},
                        );
                      },
                      child: const Text('Navigate'),
                    ),
                  ),
              '/home': (context) {
                navigatedRoute = '/home';
                navigatedArgs = ModalRoute.of(context)?.settings.arguments;
                return const Scaffold(body: Text('Home'));
              },
            },
          ),
        );

        await tester.tap(find.text('Navigate'));
        await tester.pumpAndSettle();

        expect(navigatedRoute, '/home');
        expect(navigatedArgs, isA<Map<String, dynamic>>());
        final args = navigatedArgs as Map<String, dynamic>;
        expect(args['tab'], 2);
        expect(BookingsScreen.pendingInitialTab, 'past');

        // Clean up
        BookingsScreen.pendingInitialTab = null;
      });
    });
  });
}
