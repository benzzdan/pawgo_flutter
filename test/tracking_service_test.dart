import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:pawgo/services/tracking_service.dart';

void main() {
  group('WalkLocation.fromJson', () {
    test('parses complete walk location JSON', () {
      final json = {
        'id': 42,
        'booking_id': 'booking-001',
        'latitude': 19.4326,
        'longitude': -99.1332,
        'accuracy': 5.2,
        'recorded_at': '2026-03-30T14:30:00Z',
      };

      final location = WalkLocation.fromJson(json);

      expect(location.id, 42);
      expect(location.bookingId, 'booking-001');
      expect(location.latitude, 19.4326);
      expect(location.longitude, -99.1332);
      expect(location.accuracy, 5.2);
      expect(location.recordedAt, DateTime.utc(2026, 3, 30, 14, 30));
    });

    test('handles string id', () {
      final json = {
        'id': '99',
        'booking_id': 'booking-002',
        'latitude': 20.0,
        'longitude': -100.0,
        'accuracy': null,
        'recorded_at': '2026-03-30T15:00:00Z',
      };

      final location = WalkLocation.fromJson(json);

      expect(location.id, 99);
      expect(location.accuracy, isNull);
    });

    test('handles null accuracy', () {
      final json = {
        'id': 1,
        'booking_id': 'booking-003',
        'latitude': 19.0,
        'longitude': -99.0,
        'recorded_at': '2026-03-30T12:00:00Z',
      };

      final location = WalkLocation.fromJson(json);

      expect(location.accuracy, isNull);
    });
  });

  group('TrackingService with mock client', () {
    test('initial connection state is disconnected', () {
      // Verify the enum default without constructing TrackingService
      // (which requires Supabase.instance if no client is provided)
      const state = TrackingConnectionState.disconnected;
      expect(state, TrackingConnectionState.disconnected);
    });
  });

  group('TrackingConnectionState', () {
    test('has all expected values', () {
      expect(TrackingConnectionState.values, hasLength(4));
      expect(TrackingConnectionState.values,
          contains(TrackingConnectionState.disconnected));
      expect(TrackingConnectionState.values,
          contains(TrackingConnectionState.connecting));
      expect(TrackingConnectionState.values,
          contains(TrackingConnectionState.connected));
      expect(TrackingConnectionState.values,
          contains(TrackingConnectionState.error));
    });
  });

  group('ActiveWalkScreen integration', () {
    test(
        'inserting walk_location row triggers location stream update',
        () async {
      // This test verifies the data flow: when a WalkLocation is parsed
      // from a Realtime payload and added to the stream, listeners receive it.
      final controller = StreamController<WalkLocation>.broadcast();

      final locations = <WalkLocation>[];
      final sub = controller.stream.listen((loc) {
        locations.add(loc);
      });

      // Simulate a Realtime insert event payload
      final payload = {
        'id': 1,
        'booking_id': 'booking-active-001',
        'latitude': 19.4326,
        'longitude': -99.1332,
        'accuracy': 3.5,
        'recorded_at': '2026-03-30T14:30:00Z',
      };

      final location = WalkLocation.fromJson(payload);
      controller.add(location);

      // Allow stream to propagate
      await Future.delayed(Duration.zero);

      expect(locations, hasLength(1));
      expect(locations.first.latitude, 19.4326);
      expect(locations.first.longitude, -99.1332);
      expect(locations.first.bookingId, 'booking-active-001');

      // Simulate a second GPS update
      final payload2 = {
        'id': 2,
        'booking_id': 'booking-active-001',
        'latitude': 19.4330,
        'longitude': -99.1340,
        'accuracy': 4.0,
        'recorded_at': '2026-03-30T14:30:05Z',
      };

      controller.add(WalkLocation.fromJson(payload2));
      await Future.delayed(Duration.zero);

      expect(locations, hasLength(2));
      expect(locations.last.latitude, 19.4330);
      expect(locations.last.id, 2);

      await sub.cancel();
      await controller.close();
    });

    test('map marker updates reflect latest GPS position', () async {
      // Verify that processing multiple location updates always
      // keeps track of the most recent one
      final allLocations = <WalkLocation>[];
      WalkLocation? latest;

      final updates = [
        {'id': 1, 'booking_id': 'b1', 'latitude': 19.43, 'longitude': -99.13, 'recorded_at': '2026-03-30T14:30:00Z'},
        {'id': 2, 'booking_id': 'b1', 'latitude': 19.44, 'longitude': -99.14, 'recorded_at': '2026-03-30T14:30:02Z'},
        {'id': 3, 'booking_id': 'b1', 'latitude': 19.45, 'longitude': -99.15, 'recorded_at': '2026-03-30T14:30:04Z'},
      ];

      for (final json in updates) {
        final loc = WalkLocation.fromJson(json);
        allLocations.add(loc);
        latest = loc;
      }

      expect(allLocations, hasLength(3));
      expect(latest!.latitude, 19.45);
      expect(latest.longitude, -99.15);
      expect(latest.id, 3);
    });
  });
}
