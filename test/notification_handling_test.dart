import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pawgo/services/notification_service.dart';

// Mock the dependencies
class MockFirebaseMessagingWrapper extends Mock
    implements FirebaseMessagingWrapper {}

class MockSupabaseAuthWrapper extends Mock implements SupabaseAuthWrapper {}

class MockLocalNotificationsWrapper extends Mock
    implements LocalNotificationsWrapper {}

/// Captures navigation calls for verification.
class NavigationCapture {
  final List<NotificationNavigation> calls = [];

  void navigate(NotificationNavigation nav) {
    calls.add(nav);
  }
}

void main() {
  group('NotificationRouter', () {
    test('maps booking_confirmed to /home with upcoming tab', () {
      final nav = NotificationRouter.routeFor(
        type: 'booking_confirmed',
        bookingId: 'booking-123',
      );
      expect(nav, isNotNull);
      expect(nav!.route, '/home');
      expect(nav.tab, 'upcoming');
    });

    test('maps new_message to /chat with booking_id', () {
      final nav = NotificationRouter.routeFor(
        type: 'new_message',
        bookingId: 'booking-456',
      );
      expect(nav, isNotNull);
      expect(nav!.route, '/chat');
      expect(nav.arguments?['booking_id'], 'booking-456');
    });

    test('maps walk_started to /active-walk', () {
      final nav = NotificationRouter.routeFor(
        type: 'walk_started',
        bookingId: 'booking-789',
      );
      expect(nav, isNotNull);
      expect(nav!.route, '/active-walk');
    });

    test('maps walk_completed to /home with past tab', () {
      final nav = NotificationRouter.routeFor(
        type: 'walk_completed',
        bookingId: 'booking-000',
      );
      expect(nav, isNotNull);
      expect(nav!.route, '/home');
      expect(nav.tab, 'past');
    });

    test('returns null for unknown notification type', () {
      final nav = NotificationRouter.routeFor(
        type: 'unknown_type',
        bookingId: 'booking-123',
      );
      expect(nav, isNull);
    });

    test('returns null when type is null', () {
      final nav = NotificationRouter.routeFor(
        type: null,
        bookingId: 'booking-123',
      );
      expect(nav, isNull);
    });
  });

  group('NotificationService message handling', () {
    late NotificationService service;
    late MockFirebaseMessagingWrapper mockMessaging;
    late MockSupabaseAuthWrapper mockAuth;
    late MockLocalNotificationsWrapper mockLocalNotifications;
    late NavigationCapture navCapture;

    setUp(() {
      mockMessaging = MockFirebaseMessagingWrapper();
      mockAuth = MockSupabaseAuthWrapper();
      mockLocalNotifications = MockLocalNotificationsWrapper();
      navCapture = NavigationCapture();

      // Default stubs for initialize
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

    test('foreground message triggers local notification display', () async {
      final messageController = StreamController<NotificationData>();
      when(() => mockMessaging.onMessage)
          .thenAnswer((_) => messageController.stream);

      await service.initialize();

      messageController.add(NotificationData(
        title: 'Walk Started',
        body: 'Your walker has started the walk',
        type: 'walk_started',
        bookingId: 'booking-123',
      ));
      await Future<void>.delayed(Duration.zero);

      verify(() => mockLocalNotifications.show(
            title: 'Walk Started',
            body: 'Your walker has started the walk',
            payload: any(named: 'payload'),
          )).called(1);

      await messageController.close();
    });

    test('foreground message local notification payload contains type and booking_id', () async {
      final messageController = StreamController<NotificationData>();
      when(() => mockMessaging.onMessage)
          .thenAnswer((_) => messageController.stream);

      String? capturedPayload;
      when(() => mockLocalNotifications.show(
            title: any(named: 'title'),
            body: any(named: 'body'),
            payload: any(named: 'payload'),
          )).thenAnswer((invocation) async {
        capturedPayload = invocation.namedArguments[#payload] as String?;
      });

      await service.initialize();

      messageController.add(NotificationData(
        title: 'New Message',
        body: 'You have a new message',
        type: 'new_message',
        bookingId: 'booking-456',
      ));
      await Future<void>.delayed(Duration.zero);

      expect(capturedPayload, contains('new_message'));
      expect(capturedPayload, contains('booking-456'));

      await messageController.close();
    });

    test('background notification tap navigates to correct route', () async {
      final bgController = StreamController<NotificationData>();
      when(() => mockMessaging.onMessageOpenedApp)
          .thenAnswer((_) => bgController.stream);

      await service.initialize();

      bgController.add(NotificationData(
        type: 'walk_started',
        bookingId: 'booking-789',
      ));
      await Future<void>.delayed(Duration.zero);

      expect(navCapture.calls, hasLength(1));
      expect(navCapture.calls.first.route, '/active-walk');

      await bgController.close();
    });

    test('terminated-state initial message navigates on initialize', () async {
      when(() => mockMessaging.getInitialMessage())
          .thenAnswer((_) async => NotificationData(
                type: 'booking_confirmed',
                bookingId: 'booking-init',
              ));

      await service.initialize();
      // Allow the async .then() on getInitialMessage to complete
      await Future<void>.delayed(Duration.zero);

      expect(navCapture.calls, hasLength(1));
      expect(navCapture.calls.first.route, '/home');
      expect(navCapture.calls.first.tab, 'upcoming');
    });

    test('background notification tap for new_message includes booking_id in args', () async {
      final bgController = StreamController<NotificationData>();
      when(() => mockMessaging.onMessageOpenedApp)
          .thenAnswer((_) => bgController.stream);

      await service.initialize();

      bgController.add(NotificationData(
        type: 'new_message',
        bookingId: 'booking-chat',
      ));
      await Future<void>.delayed(Duration.zero);

      expect(navCapture.calls, hasLength(1));
      expect(navCapture.calls.first.route, '/chat');
      expect(navCapture.calls.first.arguments?['booking_id'], 'booking-chat');

      await bgController.close();
    });

    test('unknown notification type does not navigate', () async {
      final bgController = StreamController<NotificationData>();
      when(() => mockMessaging.onMessageOpenedApp)
          .thenAnswer((_) => bgController.stream);

      await service.initialize();

      bgController.add(NotificationData(
        type: 'unknown_type',
        bookingId: 'booking-unknown',
      ));
      await Future<void>.delayed(Duration.zero);

      expect(navCapture.calls, isEmpty);

      await bgController.close();
    });

    test('null initial message does not navigate', () async {
      when(() => mockMessaging.getInitialMessage())
          .thenAnswer((_) async => null);

      await service.initialize();

      expect(navCapture.calls, isEmpty);
    });

    test('local notifications are initialized during service initialize', () async {
      await service.initialize();

      verify(() => mockLocalNotifications.initialize()).called(1);
    });
  });
}
