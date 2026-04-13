import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pawgo/services/notification_service.dart';

// Mock the dependencies that NotificationService uses
class MockFirebaseMessagingWrapper extends Mock
    implements FirebaseMessagingWrapper {}

class MockSupabaseAuthWrapper extends Mock implements SupabaseAuthWrapper {}

class MockLocalNotificationsWrapper extends Mock
    implements LocalNotificationsWrapper {}

void main() {
  late NotificationService service;
  late MockFirebaseMessagingWrapper mockMessaging;
  late MockSupabaseAuthWrapper mockAuth;
  late MockLocalNotificationsWrapper mockLocalNotifications;

  setUp(() {
    mockMessaging = MockFirebaseMessagingWrapper();
    mockAuth = MockSupabaseAuthWrapper();
    mockLocalNotifications = MockLocalNotificationsWrapper();

    // Default stubs for message handling (not under test here)
    when(() => mockMessaging.onMessage)
        .thenAnswer((_) => const Stream<NotificationData>.empty());
    when(() => mockMessaging.onMessageOpenedApp)
        .thenAnswer((_) => const Stream<NotificationData>.empty());
    when(() => mockMessaging.getInitialMessage())
        .thenAnswer((_) async => null);
    when(() => mockLocalNotifications.initialize())
        .thenAnswer((_) async {});

    service = NotificationService.forTesting(
      messaging: mockMessaging,
      auth: mockAuth,
      localNotifications: mockLocalNotifications,
    );
  });

  group('NotificationService', () {
    test('is a singleton via .instance', () {
      // The static instance should not be null
      expect(NotificationService.instance, isA<NotificationService>());
    });

    test('requests permission on initialize', () async {
      when(() => mockMessaging.requestPermission()).thenAnswer(
        (_) async => true,
      );
      when(() => mockMessaging.getToken()).thenAnswer(
        (_) async => 'test-fcm-token',
      );
      when(() => mockAuth.getCurrentUserId()).thenReturn('user-123');
      when(() => mockAuth.getFcmTokens()).thenAnswer((_) async => <String>[]);
      when(() => mockAuth.updateFcmTokens(any())).thenAnswer((_) async {});
      when(() => mockMessaging.onTokenRefresh)
          .thenAnswer((_) => const Stream<String>.empty());

      await service.initialize();

      verify(() => mockMessaging.requestPermission()).called(1);
    });

    test('gets FCM token after permission granted', () async {
      when(() => mockMessaging.requestPermission()).thenAnswer(
        (_) async => true,
      );
      when(() => mockMessaging.getToken()).thenAnswer(
        (_) async => 'test-fcm-token',
      );
      when(() => mockAuth.getCurrentUserId()).thenReturn('user-123');
      when(() => mockAuth.getFcmTokens()).thenAnswer((_) async => <String>[]);
      when(() => mockAuth.updateFcmTokens(any())).thenAnswer((_) async {});
      when(() => mockMessaging.onTokenRefresh)
          .thenAnswer((_) => const Stream<String>.empty());

      await service.initialize();

      verify(() => mockMessaging.getToken()).called(1);
    });

    test('does not get token when permission denied', () async {
      when(() => mockMessaging.requestPermission()).thenAnswer(
        (_) async => false,
      );
      when(() => mockMessaging.onTokenRefresh)
          .thenAnswer((_) => const Stream<String>.empty());

      await service.initialize();

      verifyNever(() => mockMessaging.getToken());
    });

    test('stores FCM token in user metadata via updateFcmTokens', () async {
      when(() => mockMessaging.requestPermission()).thenAnswer(
        (_) async => true,
      );
      when(() => mockMessaging.getToken()).thenAnswer(
        (_) async => 'new-token',
      );
      when(() => mockAuth.getCurrentUserId()).thenReturn('user-123');
      when(() => mockAuth.getFcmTokens()).thenAnswer((_) async => <String>[]);
      when(() => mockAuth.updateFcmTokens(any())).thenAnswer((_) async {});
      when(() => mockMessaging.onTokenRefresh)
          .thenAnswer((_) => const Stream<String>.empty());

      await service.initialize();

      verify(() => mockAuth.updateFcmTokens(['new-token'])).called(1);
    });

    test('appends token to existing tokens without duplicates', () async {
      when(() => mockMessaging.requestPermission()).thenAnswer(
        (_) async => true,
      );
      when(() => mockMessaging.getToken()).thenAnswer(
        (_) async => 'new-token',
      );
      when(() => mockAuth.getCurrentUserId()).thenReturn('user-123');
      when(() => mockAuth.getFcmTokens())
          .thenAnswer((_) async => ['existing-token']);
      when(() => mockAuth.updateFcmTokens(any())).thenAnswer((_) async {});
      when(() => mockMessaging.onTokenRefresh)
          .thenAnswer((_) => const Stream<String>.empty());

      await service.initialize();

      verify(() =>
              mockAuth.updateFcmTokens(['existing-token', 'new-token']))
          .called(1);
    });

    test('does not duplicate token if already registered', () async {
      when(() => mockMessaging.requestPermission()).thenAnswer(
        (_) async => true,
      );
      when(() => mockMessaging.getToken()).thenAnswer(
        (_) async => 'existing-token',
      );
      when(() => mockAuth.getCurrentUserId()).thenReturn('user-123');
      when(() => mockAuth.getFcmTokens())
          .thenAnswer((_) async => ['existing-token']);
      when(() => mockAuth.updateFcmTokens(any())).thenAnswer((_) async {});
      when(() => mockMessaging.onTokenRefresh)
          .thenAnswer((_) => const Stream<String>.empty());

      await service.initialize();

      // Should not call updateFcmTokens since token already exists
      verifyNever(() => mockAuth.updateFcmTokens(any()));
    });

    test('listens to onTokenRefresh and updates tokens', () async {
      final tokenController = StreamController<String>();

      when(() => mockMessaging.requestPermission()).thenAnswer(
        (_) async => true,
      );
      when(() => mockMessaging.getToken()).thenAnswer(
        (_) async => 'initial-token',
      );
      when(() => mockAuth.getCurrentUserId()).thenReturn('user-123');
      when(() => mockAuth.getFcmTokens()).thenAnswer((_) async => <String>[]);
      when(() => mockAuth.updateFcmTokens(any())).thenAnswer((_) async {});
      when(() => mockMessaging.onTokenRefresh)
          .thenAnswer((_) => tokenController.stream);

      await service.initialize();

      // Reset so we can verify the refresh call separately
      reset(mockAuth);
      when(() => mockAuth.getCurrentUserId()).thenReturn('user-123');
      when(() => mockAuth.getFcmTokens())
          .thenAnswer((_) async => ['initial-token']);
      when(() => mockAuth.updateFcmTokens(any())).thenAnswer((_) async {});

      // Emit a new token via refresh
      tokenController.add('refreshed-token');
      await Future<void>.delayed(Duration.zero);

      verify(() =>
              mockAuth.updateFcmTokens(['initial-token', 'refreshed-token']))
          .called(1);

      await tokenController.close();
    });

    test('removeToken removes current device token on sign-out', () async {
      when(() => mockMessaging.requestPermission()).thenAnswer(
        (_) async => true,
      );
      when(() => mockMessaging.getToken()).thenAnswer(
        (_) async => 'device-token',
      );
      when(() => mockAuth.getCurrentUserId()).thenReturn('user-123');
      when(() => mockAuth.getFcmTokens())
          .thenAnswer((_) async => <String>[]);
      when(() => mockAuth.updateFcmTokens(any())).thenAnswer((_) async {});
      when(() => mockMessaging.onTokenRefresh)
          .thenAnswer((_) => const Stream<String>.empty());

      await service.initialize();

      // Reset to track removeToken calls
      reset(mockAuth);
      when(() => mockAuth.getCurrentUserId()).thenReturn('user-123');
      when(() => mockAuth.getFcmTokens())
          .thenAnswer((_) async => ['device-token', 'other-token']);
      when(() => mockAuth.updateFcmTokens(any())).thenAnswer((_) async {});

      await service.removeToken();

      verify(() => mockAuth.updateFcmTokens(['other-token'])).called(1);
    });

    test('removeToken is safe when no current token', () async {
      // No initialize called, so no current token
      await service.removeToken();

      // Should not throw and should not call updateFcmTokens
      verifyNever(() => mockAuth.updateFcmTokens(any()));
    });

    test('dispose cancels token refresh subscription', () async {
      final tokenController = StreamController<String>();

      when(() => mockMessaging.requestPermission()).thenAnswer(
        (_) async => true,
      );
      when(() => mockMessaging.getToken()).thenAnswer(
        (_) async => 'token',
      );
      when(() => mockAuth.getCurrentUserId()).thenReturn('user-123');
      when(() => mockAuth.getFcmTokens()).thenAnswer((_) async => <String>[]);
      when(() => mockAuth.updateFcmTokens(any())).thenAnswer((_) async {});
      when(() => mockMessaging.onTokenRefresh)
          .thenAnswer((_) => tokenController.stream);

      await service.initialize();
      service.dispose();

      // After dispose, token refresh events should not trigger updates
      reset(mockAuth);
      tokenController.add('post-dispose-token');
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => mockAuth.updateFcmTokens(any()));

      await tokenController.close();
    });
  });
}
