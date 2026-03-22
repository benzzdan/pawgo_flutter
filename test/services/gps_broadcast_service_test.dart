import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:pawgo/services/gps_broadcast_service.dart';

// --- Mocks ---

class MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {}

// --- Helpers ---

Position createTestPosition({
  double latitude = 19.4326,
  double longitude = -99.1332,
  double accuracy = 5.0,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2026, 3, 22),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  late GpsBroadcastService service;
  late MockGeolocatorPlatform mockGeolocator;

  setUpAll(() {
    registerFallbackValue(const LocationSettings());
  });

  setUp(() {
    service = GpsBroadcastService.instance;
    service.resetForTesting();

    mockGeolocator = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocator;
  });

  tearDown(() {
    service.resetForTesting();
  });

  void stubPermissionGranted() {
    when(() => mockGeolocator.isLocationServiceEnabled())
        .thenAnswer((_) async => true);
    when(() => mockGeolocator.checkPermission())
        .thenAnswer((_) async => LocationPermission.whileInUse);
    when(() => mockGeolocator.getCurrentPosition(
          locationSettings: any(named: 'locationSettings'),
        )).thenAnswer((_) async => createTestPosition());
  }

  group('GpsBroadcastService - initial state', () {
    test('is not broadcasting initially', () {
      expect(service.isBroadcasting, isFalse);
      expect(service.activeBookingId, isNull);
      expect(service.lastPosition, isNull);
      expect(service.positionNotifier.value, isNull);
    });
  });

  group('GpsBroadcastService - startBroadcasting', () {
    test('returns true and sets state when permission granted', () async {
      stubPermissionGranted();

      final result = await service.startBroadcasting('booking-123');

      expect(result, isTrue);
      expect(service.isBroadcasting, isTrue);
      expect(service.activeBookingId, 'booking-123');
    });

    test('captures initial GPS position on start', () async {
      stubPermissionGranted();

      await service.startBroadcasting('booking-123');

      expect(service.lastPosition, isNotNull);
      expect(service.lastPosition!.latitude, 19.4326);
      expect(service.lastPosition!.longitude, -99.1332);
      expect(service.positionNotifier.value, isNotNull);
    });

    test('returns false when location services disabled', () async {
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => false);

      final result = await service.startBroadcasting('booking-123');

      expect(result, isFalse);
      expect(service.isBroadcasting, isFalse);
    });

    test('returns false when permission denied', () async {
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => LocationPermission.denied);
      when(() => mockGeolocator.requestPermission())
          .thenAnswer((_) async => LocationPermission.denied);

      final result = await service.startBroadcasting('booking-123');

      expect(result, isFalse);
      expect(service.isBroadcasting, isFalse);
    });

    test('returns false when permission permanently denied', () async {
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => LocationPermission.deniedForever);

      final result = await service.startBroadcasting('booking-123');

      expect(result, isFalse);
      expect(service.isBroadcasting, isFalse);
    });

    test('returns true without restart when already broadcasting same booking',
        () async {
      stubPermissionGranted();

      await service.startBroadcasting('booking-123');
      final secondResult = await service.startBroadcasting('booking-123');

      expect(secondResult, isTrue);
      expect(service.isBroadcasting, isTrue);
      // getCurrentPosition called only once (on first start)
      verify(() => mockGeolocator.getCurrentPosition(
            locationSettings: any(named: 'locationSettings'),
          )).called(1);
    });
  });

  group('GpsBroadcastService - stopBroadcasting', () {
    test('resets all broadcasting state', () async {
      stubPermissionGranted();
      await service.startBroadcasting('booking-123');

      service.stopBroadcasting();

      expect(service.isBroadcasting, isFalse);
      expect(service.activeBookingId, isNull);
    });

    test('GPS updates stop when walk is completed (stopBroadcasting)', () {
      fakeAsync((async) {
        when(() => mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) => Future.value(true));
        when(() => mockGeolocator.checkPermission())
            .thenAnswer((_) => Future.value(LocationPermission.whileInUse));

        int captureCount = 0;
        when(() => mockGeolocator.getCurrentPosition(
              locationSettings: any(named: 'locationSettings'),
            )).thenAnswer((_) {
          captureCount++;
          return Future.value(createTestPosition());
        });

        service.startBroadcasting('booking-123');
        async.flushMicrotasks();

        expect(captureCount, 1); // Initial capture

        // 1 timer tick
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(captureCount, 2);

        // Stop broadcasting (walk completed)
        service.stopBroadcasting();

        // No more captures after stop
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();
        expect(captureCount, 2); // Still 2 — timer was cancelled
      });
    });
  });

  group('GpsBroadcastService - periodic GPS capture', () {
    test('captures position every 5 seconds', () {
      fakeAsync((async) {
        when(() => mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) => Future.value(true));
        when(() => mockGeolocator.checkPermission())
            .thenAnswer((_) => Future.value(LocationPermission.whileInUse));

        int captureCount = 0;
        when(() => mockGeolocator.getCurrentPosition(
              locationSettings: any(named: 'locationSettings'),
            )).thenAnswer((_) {
          captureCount++;
          return Future.value(createTestPosition());
        });

        service.startBroadcasting('booking-123');
        async.flushMicrotasks();
        expect(captureCount, 1); // Initial

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(captureCount, 2); // 1st tick

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(captureCount, 3); // 2nd tick

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(captureCount, 4); // 3rd tick

        service.stopBroadcasting();
      });
    });

    test('positionNotifier updates on each capture', () {
      fakeAsync((async) {
        when(() => mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) => Future.value(true));
        when(() => mockGeolocator.checkPermission())
            .thenAnswer((_) => Future.value(LocationPermission.whileInUse));

        int callIndex = 0;
        final positions = [
          createTestPosition(latitude: 19.43, longitude: -99.13),
          createTestPosition(latitude: 19.44, longitude: -99.14),
        ];

        when(() => mockGeolocator.getCurrentPosition(
              locationSettings: any(named: 'locationSettings'),
            )).thenAnswer((_) {
          final p = positions[callIndex.clamp(0, positions.length - 1)];
          callIndex++;
          return Future.value(p);
        });

        service.startBroadcasting('booking-123');
        async.flushMicrotasks();

        expect(service.positionNotifier.value?.latitude, 19.43);

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(service.positionNotifier.value?.latitude, 19.44);

        service.stopBroadcasting();
      });
    });

    test('error during capture does not stop broadcasting', () {
      fakeAsync((async) {
        when(() => mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) => Future.value(true));
        when(() => mockGeolocator.checkPermission())
            .thenAnswer((_) => Future.value(LocationPermission.whileInUse));

        int captureCount = 0;
        when(() => mockGeolocator.getCurrentPosition(
              locationSettings: any(named: 'locationSettings'),
            )).thenAnswer((_) {
          captureCount++;
          if (captureCount == 2) {
            return Future.error(Exception('GPS error'));
          }
          return Future.value(createTestPosition());
        });

        service.startBroadcasting('booking-123');
        async.flushMicrotasks();
        expect(captureCount, 1);
        expect(service.isBroadcasting, isTrue);

        // 2nd capture throws
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(captureCount, 2);
        expect(service.isBroadcasting, isTrue); // Still broadcasting

        // 3rd capture works
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(captureCount, 3);

        service.stopBroadcasting();
      });
    });
  });
}
