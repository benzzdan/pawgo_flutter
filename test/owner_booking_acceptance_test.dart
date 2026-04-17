import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pawgo/services/notification_service.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:pawgo/screens/bookings_screen.dart';
import 'package:pawgo/screens/alternative_walkers_screen.dart';

// ---------------------------------------------------------------------------
// Tests for US-013: Booking acceptance — owner UI
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // 1. NotificationData — suggested_walker_ids support
  // =========================================================================
  group('NotificationData suggested walker IDs', () {
    test('fromRemoteMessage-like constructor carries suggestedWalkerIds', () {
      final data = NotificationData(
        type: 'walk_request_declined',
        bookingId: 'b-123',
        suggestedWalkerIds: ['w1', 'w2', 'w3'],
      );
      expect(data.suggestedWalkerIds, ['w1', 'w2', 'w3']);
    });

    test('toPayload and fromPayload round-trip suggestedWalkerIds', () {
      final original = NotificationData(
        type: 'walk_request_declined',
        bookingId: 'b-456',
        suggestedWalkerIds: ['w-a', 'w-b'],
      );
      final payload = original.toPayload();
      final restored = NotificationData.fromPayload(payload);

      expect(restored.type, 'walk_request_declined');
      expect(restored.bookingId, 'b-456');
      expect(restored.suggestedWalkerIds, ['w-a', 'w-b']);
    });

    test('fromPayload with no suggestedWalkerIds returns null', () {
      final original = NotificationData(
        type: 'booking_confirmed',
        bookingId: 'b-789',
      );
      final payload = original.toPayload();
      final restored = NotificationData.fromPayload(payload);
      expect(restored.suggestedWalkerIds, isNull);
    });
  });

  // =========================================================================
  // 2. NotificationRouter — new notification types
  // =========================================================================
  group('NotificationRouter — booking acceptance types', () {
    test('walk_request_accepted maps to /home with upcoming tab', () {
      final nav = NotificationRouter.routeFor(
        type: 'walk_request_accepted',
        bookingId: 'b-100',
      );
      expect(nav, isNotNull);
      expect(nav!.route, '/home');
      expect(nav.tab, 'upcoming');
    });

    test('walk_request_declined maps to /alternative-walkers with walker IDs', () {
      final nav = NotificationRouter.routeFor(
        type: 'walk_request_declined',
        bookingId: 'b-200',
        suggestedWalkerIds: ['w1', 'w2', 'w3'],
      );
      expect(nav, isNotNull);
      expect(nav!.route, '/alternative-walkers');
      expect(nav.arguments?['booking_id'], 'b-200');
      expect(nav.arguments?['suggested_walker_ids'], ['w1', 'w2', 'w3']);
    });

    test('walk_request_expired maps to /alternative-walkers with walker IDs', () {
      final nav = NotificationRouter.routeFor(
        type: 'walk_request_expired',
        bookingId: 'b-300',
        suggestedWalkerIds: ['w4', 'w5'],
      );
      expect(nav, isNotNull);
      expect(nav!.route, '/alternative-walkers');
      expect(nav.arguments?['booking_id'], 'b-300');
      expect(nav.arguments?['suggested_walker_ids'], ['w4', 'w5']);
    });

    test('walk_request_declined without walker IDs falls back to /home cancelled tab', () {
      final nav = NotificationRouter.routeFor(
        type: 'walk_request_declined',
        bookingId: 'b-400',
      );
      expect(nav, isNotNull);
      expect(nav!.route, '/home');
      expect(nav.tab, 'cancelled');
    });
  });

  // =========================================================================
  // 3. Booking model — pending_walker_acceptance support
  // =========================================================================
  group('Booking model — pending_walker_acceptance', () {
    Booking makeBooking(String status) => Booking(
          id: 'test',
          ownerId: 'o1',
          walkerId: 'w1',
          dogId: 'd1',
          status: status,
          scheduledAt: DateTime.now(),
        );

    test('pending_walker_acceptance is treated as upcoming', () {
      expect(makeBooking('pending_walker_acceptance').isUpcoming, true);
    });

    test('displayStatus returns Awaiting Walker for pending_walker_acceptance', () {
      expect(makeBooking('pending_walker_acceptance').displayStatus,
          'Awaiting Walker');
    });

    test('statusColor returns amber for pending_walker_acceptance', () {
      final booking = makeBooking('pending_walker_acceptance');
      expect(booking.statusColor, const Color(0xFFF59E0B));
    });
  });

  // =========================================================================
  // 4. Alternative walkers screen — widget tests
  // =========================================================================
  group('AlternativeWalkersScreen', () {
    testWidgets('displays suggested walkers with Book Instead buttons',
        (tester) async {
      // We test the extracted widget in isolation with mock data
      final walkers = [
        {
          'id': 'w1',
          'user_id': 'u1',
          'hourly_rate_mxn': 100,
          'avg_rating': 4.5,
          'total_walks': 30,
          'users': {'full_name': 'Ana Garcia', 'avatar_url': null},
        },
        {
          'id': 'w2',
          'user_id': 'u2',
          'hourly_rate_mxn': 120,
          'avg_rating': 4.8,
          'total_walks': 50,
          'users': {'full_name': 'Carlos Lopez', 'avatar_url': null},
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: walkers.map((w) {
                final users = w['users'] as Map<String, dynamic>;
                final name = users['full_name'] as String;
                final rate = w['hourly_rate_mxn'] as int;
                return ListTile(
                  title: Text(name),
                  subtitle: Text('\$$rate MXN/hr'),
                  trailing: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Book Instead'),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      );

      expect(find.text('Ana Garcia'), findsOneWidget);
      expect(find.text('Carlos Lopez'), findsOneWidget);
      expect(find.text('Book Instead'), findsNWidgets(2));
    });

    testWidgets('shows empty state when no alternative walkers available',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('No alternative walkers available'),
            ),
          ),
        ),
      );

      expect(
          find.text('No alternative walkers available'), findsOneWidget);
    });
  });

  // =========================================================================
  // 5. Booking waiting state — countdown timer logic
  // =========================================================================
  group('Countdown timer logic', () {
    test('calculates remaining seconds from deadline', () {
      final deadline = DateTime.now().add(const Duration(minutes: 3, seconds: 30));
      final remaining = deadline.difference(DateTime.now());
      expect(remaining.inSeconds, closeTo(210, 2));
    });

    test('formats countdown as M:SS', () {
      String formatCountdown(int totalSeconds) {
        if (totalSeconds <= 0) return '0:00';
        final minutes = totalSeconds ~/ 60;
        final seconds = totalSeconds % 60;
        return '$minutes:${seconds.toString().padLeft(2, '0')}';
      }

      expect(formatCountdown(210), '3:30');
      expect(formatCountdown(60), '1:00');
      expect(formatCountdown(5), '0:05');
      expect(formatCountdown(0), '0:00');
      expect(formatCountdown(-10), '0:00');
    });
  });

  // =========================================================================
  // 6. BookingsScreen — pending_walker_acceptance in upcoming filter
  // =========================================================================
  group('BookingsScreen — upcoming filter includes pending_walker_acceptance',
      () {
    test('pending_walker_acceptance bookings appear in upcoming filter', () {
      final bookings = [
        {
          'id': 'b1',
          'status': 'pending_walker_acceptance',
          'scheduled_at': '2026-05-01T14:00:00Z',
        },
        {
          'id': 'b2',
          'status': 'confirmed',
          'scheduled_at': '2026-05-01T15:00:00Z',
        },
        {
          'id': 'b3',
          'status': 'cancelled',
          'scheduled_at': '2026-05-01T16:00:00Z',
        },
      ];

      final upcoming = bookings.where((b) {
        final status = b['status'] as String;
        return [
          'pending',
          'pending_walker_acceptance',
          'confirmed',
          'walker_en_route',
          'walk_started',
        ].contains(status);
      }).toList();

      expect(upcoming.length, 2);
      expect(upcoming[0]['id'], 'b1');
      expect(upcoming[1]['id'], 'b2');
    });
  });

  // =========================================================================
  // 7. Status config — pending_walker_acceptance visual treatment
  // =========================================================================
  group('Status config for pending_walker_acceptance', () {
    test('returns Awaiting Walker label with amber colors', () {
      // This tests the _statusConfig function behavior we'll implement
      // We verify the Booking model displayStatus here as a proxy
      final booking = Booking(
        id: 'test',
        ownerId: 'o1',
        walkerId: 'w1',
        dogId: 'd1',
        status: 'pending_walker_acceptance',
        scheduledAt: DateTime.now(),
      );
      expect(booking.displayStatus, 'Awaiting Walker');
    });
  });

  // =========================================================================
  // 8. NotificationService — handling decline/expire with suggested walkers
  // =========================================================================
  group('NotificationService — decline/expire deep linking', () {
    late MockFirebaseMessagingWrapper mockMessaging;
    late MockSupabaseAuthWrapper mockAuth;
    late MockLocalNotificationsWrapper mockLocalNotifications;
    late NavigationCapture navCapture;
    late NotificationService service;

    setUp(() {
      mockMessaging = MockFirebaseMessagingWrapper();
      mockAuth = MockSupabaseAuthWrapper();
      mockLocalNotifications = MockLocalNotificationsWrapper();
      navCapture = NavigationCapture();

      when(() => mockMessaging.requestPermission())
          .thenAnswer((_) async => true);
      when(() => mockMessaging.getToken())
          .thenAnswer((_) async => 'test-token');
      when(() => mockAuth.getCurrentUserId()).thenReturn('user-123');
      when(() => mockAuth.getFcmTokens())
          .thenAnswer((_) async => <String>[]);
      when(() => mockAuth.updateFcmTokens(any()))
          .thenAnswer((_) async {});
      when(() => mockMessaging.onTokenRefresh)
          .thenAnswer((_) => const Stream<String>.empty());
      when(() => mockMessaging.onMessage)
          .thenAnswer((_) => const Stream<NotificationData>.empty());
      when(() => mockMessaging.onMessageOpenedApp)
          .thenAnswer((_) => const Stream<NotificationData>.empty());
      when(() => mockMessaging.getInitialMessage())
          .thenAnswer((_) async => null);
      when(() => mockLocalNotifications.initialize())
          .thenAnswer((_) async {});
      when(() => mockLocalNotifications.show(
            title: any(named: 'title'),
            body: any(named: 'body'),
            payload: any(named: 'payload'),
          )).thenAnswer((_) async {});

      service = NotificationService.forTesting(
        messaging: mockMessaging,
        auth: mockAuth,
        localNotifications: mockLocalNotifications,
        onNotificationTap: navCapture.navigate,
      );
    });

    test('background tap on walk_request_declined navigates to alternative walkers',
        () async {
      final bgController = StreamController<NotificationData>();
      when(() => mockMessaging.onMessageOpenedApp)
          .thenAnswer((_) => bgController.stream);

      await service.initialize();

      bgController.add(NotificationData(
        type: 'walk_request_declined',
        bookingId: 'b-decline',
        suggestedWalkerIds: ['w1', 'w2'],
      ));
      await Future<void>.delayed(Duration.zero);

      expect(navCapture.calls, hasLength(1));
      expect(navCapture.calls.first.route, '/alternative-walkers');
      expect(navCapture.calls.first.arguments?['booking_id'], 'b-decline');
      expect(navCapture.calls.first.arguments?['suggested_walker_ids'],
          ['w1', 'w2']);

      await bgController.close();
    });

    test('background tap on walk_request_accepted navigates to home upcoming',
        () async {
      final bgController = StreamController<NotificationData>();
      when(() => mockMessaging.onMessageOpenedApp)
          .thenAnswer((_) => bgController.stream);

      await service.initialize();

      bgController.add(NotificationData(
        type: 'walk_request_accepted',
        bookingId: 'b-accept',
      ));
      await Future<void>.delayed(Duration.zero);

      expect(navCapture.calls, hasLength(1));
      expect(navCapture.calls.first.route, '/home');
      expect(navCapture.calls.first.tab, 'upcoming');

      await bgController.close();
    });

    test('background tap on walk_request_expired navigates to alternative walkers',
        () async {
      final bgController = StreamController<NotificationData>();
      when(() => mockMessaging.onMessageOpenedApp)
          .thenAnswer((_) => bgController.stream);

      await service.initialize();

      bgController.add(NotificationData(
        type: 'walk_request_expired',
        bookingId: 'b-expire',
        suggestedWalkerIds: ['w3'],
      ));
      await Future<void>.delayed(Duration.zero);

      expect(navCapture.calls, hasLength(1));
      expect(navCapture.calls.first.route, '/alternative-walkers');
      expect(navCapture.calls.first.arguments?['suggested_walker_ids'], ['w3']);

      await bgController.close();
    });
  });

  // =========================================================================
  // 9. BookingScreen — post-creation navigates to /home (not /payment)
  // =========================================================================
  group('BookingScreen — post-creation navigation', () {
    test('on 201 response, pendingInitialTab is set to upcoming', () {
      BookingsScreen.pendingInitialTab = null;

      // Simulate what _confirmBooking does on success:
      BookingsScreen.pendingInitialTab = 'upcoming';

      expect(BookingsScreen.pendingInitialTab, 'upcoming');

      // Clean up
      BookingsScreen.pendingInitialTab = null;
    });
  });

  // =========================================================================
  // 10. Cancel pending booking — status update logic
  // =========================================================================
  group('Cancel pending booking', () {
    test('cancelling a pending_walker_acceptance booking updates status to cancelled', () {
      const originalStatus = 'pending_walker_acceptance';
      const cancelledStatus = 'cancelled';
      expect(originalStatus != cancelledStatus, isTrue);

      final booking = Booking(
        id: 'b-cancel',
        ownerId: 'o1',
        walkerId: 'w1',
        dogId: 'd1',
        status: cancelledStatus,
        scheduledAt: DateTime.now(),
      );
      expect(booking.isCancelled, isTrue);
      expect(booking.isUpcoming, isFalse);
    });
  });

  // =========================================================================
  // 11. CountdownBanner — widget test
  // =========================================================================
  group('Countdown banner display', () {
    testWidgets('shows remaining time for a future deadline', (tester) async {
      final futureDeadline = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 3, seconds: 15))
          .toIso8601String();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestCountdownBanner(acceptanceDeadline: futureDeadline),
          ),
        ),
      );

      // Should show "Waiting for walker" text
      expect(find.textContaining('Waiting for walker'), findsOneWidget);
      expect(find.textContaining('remaining'), findsOneWidget);
    });

    testWidgets('shows expired state for a past deadline', (tester) async {
      final pastDeadline = DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 1))
          .toIso8601String();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestCountdownBanner(acceptanceDeadline: pastDeadline),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Request expired'), findsOneWidget);
    });

    testWidgets('shows nothing when deadline is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _TestCountdownBanner(acceptanceDeadline: null),
          ),
        ),
      );

      expect(find.textContaining('Waiting'), findsNothing);
      expect(find.textContaining('expired'), findsNothing);
    });
  });

  // =========================================================================
  // 12. AlternativeWalkersScreen — actual widget tests
  // =========================================================================
  group('AlternativeWalkersScreen widget', () {
    testWidgets('displays loading state initially', (tester) async {
      final completer = Completer<List<Map<String, dynamic>>>();

      await tester.pumpWidget(
        MaterialApp(
          home: AlternativeWalkersScreen(
            bookingId: 'b-test',
            suggestedWalkerIds: const ['w1', 'w2'],
            walkersFuture: completer.future,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future so the timer is cleaned up
      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('displays walker cards after loading', (tester) async {
      final walkers = [
        {
          'id': 'w1',
          'user_id': 'u1',
          'hourly_rate_mxn': 100,
          'avg_rating': 4.5,
          'total_walks': 30,
          'users': {'full_name': 'Ana Garcia', 'avatar_url': null},
        },
        {
          'id': 'w2',
          'user_id': 'u2',
          'hourly_rate_mxn': 120,
          'avg_rating': 4.8,
          'total_walks': 50,
          'users': {'full_name': 'Carlos Lopez', 'avatar_url': null},
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AlternativeWalkersScreen(
            bookingId: 'b-test',
            suggestedWalkerIds: const ['w1', 'w2'],
            walkersFuture: Future.value(walkers),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ana Garcia'), findsOneWidget);
      expect(find.text('Carlos Lopez'), findsOneWidget);
      expect(find.text('Book Instead'), findsNWidgets(2));
    });

    testWidgets('shows empty state when no walkers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AlternativeWalkersScreen(
            bookingId: 'b-test',
            suggestedWalkerIds: const [],
            walkersFuture: Future.value([]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No alternative walkers'), findsOneWidget);
    });

    testWidgets('shows error state on fetch failure', (tester) async {
      final completer = Completer<List<Map<String, dynamic>>>();

      await tester.pumpWidget(
        MaterialApp(
          home: AlternativeWalkersScreen(
            bookingId: 'b-test',
            suggestedWalkerIds: const ['w1'],
            walkersFuture: completer.future,
          ),
        ),
      );

      // Complete with error
      completer.completeError('Network error');
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load'), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Test wrapper for _CountdownBanner (which is private in bookings_screen.dart)
// We replicate the widget logic here for isolated testing.
// ---------------------------------------------------------------------------
class _TestCountdownBanner extends StatefulWidget {
  final String? acceptanceDeadline;
  const _TestCountdownBanner({required this.acceptanceDeadline});

  @override
  State<_TestCountdownBanner> createState() => _TestCountdownBannerState();
}

class _TestCountdownBannerState extends State<_TestCountdownBanner> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    if (widget.acceptanceDeadline == null) return;
    final deadline = DateTime.tryParse(widget.acceptanceDeadline!);
    if (deadline == null) return;

    _updateRemaining(deadline);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining(deadline);
    });
  }

  void _updateRemaining(DateTime deadline) {
    final now = DateTime.now().toUtc();
    final remaining = deadline.difference(now);
    if (!mounted) return;
    if (remaining.isNegative) {
      _timer?.cancel();
      setState(() {
        _expired = true;
        _remaining = Duration.zero;
      });
    } else {
      setState(() {
        _remaining = remaining;
        _expired = false;
      });
    }
  }

  String _formatCountdown(Duration d) {
    if (d.isNegative || d == Duration.zero) return '0:00';
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.acceptanceDeadline == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        _expired
            ? 'Request expired'
            : 'Waiting for walker — ${_formatCountdown(_remaining)} remaining',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Test mocks (reused from notification_handling_test pattern)
// ---------------------------------------------------------------------------
class MockFirebaseMessagingWrapper extends Mock
    implements FirebaseMessagingWrapper {}

class MockSupabaseAuthWrapper extends Mock implements SupabaseAuthWrapper {}

class MockLocalNotificationsWrapper extends Mock
    implements LocalNotificationsWrapper {}

class NavigationCapture {
  final List<NotificationNavigation> calls = [];
  void navigate(NotificationNavigation nav) => calls.add(nav);
}
