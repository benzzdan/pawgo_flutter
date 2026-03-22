import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pawgo/services/realtime_manager.dart';

// --- Mocks ---

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockRealtimeChannel extends Mock implements RealtimeChannel {}

// --- Helpers ---

void _noOpCallback(PostgresChangePayload _) {}

void main() {
  late MockSupabaseClient mockClient;
  late MockRealtimeChannel mockChannel;

  setUpAll(() {
    registerFallbackValue(PostgresChangeEvent.insert);
    registerFallbackValue(PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'id',
      value: 'test',
    ));
    registerFallbackValue(_noOpCallback);
    registerFallbackValue(
        (RealtimeSubscribeStatus s, [Object? e]) {});
  });

  setUp(() {
    mockClient = MockSupabaseClient();
    mockChannel = MockRealtimeChannel();

    when(() => mockClient.channel(any())).thenReturn(mockChannel);
    when(() => mockChannel.onPostgresChanges(
          event: any(named: 'event'),
          schema: any(named: 'schema'),
          table: any(named: 'table'),
          filter: any(named: 'filter'),
          callback: any(named: 'callback'),
        )).thenReturn(mockChannel);
    when(() => mockChannel.subscribe(any())).thenReturn(mockChannel);
    when(() => mockChannel.unsubscribe()).thenAnswer((_) async => 'ok');
  });

  group('RealtimeManager - subscribe', () {
    test('creates channel with correct name', () {
      final manager = RealtimeManager(
        client: mockClient,
        channelName: 'gps_booking_123',
        table: 'walk_locations',
        event: PostgresChangeEvent.insert,
        onData: _noOpCallback,
      );

      manager.subscribe();

      verify(() => mockClient.channel('gps_booking_123')).called(1);
      manager.dispose();
    });

    test('configures postgres changes with correct table and event', () {
      final manager = RealtimeManager(
        client: mockClient,
        channelName: 'gps_test',
        table: 'walk_locations',
        event: PostgresChangeEvent.insert,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'booking_id',
          value: 'booking-123',
        ),
        onData: _noOpCallback,
      );

      manager.subscribe();

      verify(() => mockChannel.onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'walk_locations',
            filter: any(named: 'filter'),
            callback: any(named: 'callback'),
          )).called(1);
      manager.dispose();
    });

    test('calls subscribe on the channel', () {
      final manager = RealtimeManager(
        client: mockClient,
        channelName: 'test',
        table: 'walk_locations',
        event: PostgresChangeEvent.insert,
        onData: _noOpCallback,
      );

      manager.subscribe();

      verify(() => mockChannel.subscribe(any())).called(1);
      manager.dispose();
    });

    test('delivers data to onData callback when payload received', () {
      void Function(PostgresChangePayload)? capturedCallback;

      when(() => mockChannel.onPostgresChanges(
            event: any(named: 'event'),
            schema: any(named: 'schema'),
            table: any(named: 'table'),
            filter: any(named: 'filter'),
            callback: any(named: 'callback'),
          )).thenAnswer((invocation) {
        capturedCallback = invocation.namedArguments[#callback]
            as void Function(PostgresChangePayload);
        return mockChannel;
      });

      final receivedPayloads = <PostgresChangePayload>[];
      final manager = RealtimeManager(
        client: mockClient,
        channelName: 'test',
        table: 'walk_locations',
        event: PostgresChangeEvent.insert,
        onData: (payload) => receivedPayloads.add(payload),
      );

      manager.subscribe();
      expect(capturedCallback, isNotNull);

      // Simulate receiving GPS data
      final mockPayload = MockPostgresChangePayload();
      capturedCallback!(mockPayload);

      expect(receivedPayloads, hasLength(1));
      expect(receivedPayloads.first, mockPayload);
      manager.dispose();
    });
  });

  group('RealtimeManager - dispose', () {
    test('unsubscribes channel on dispose', () {
      final manager = RealtimeManager(
        client: mockClient,
        channelName: 'test',
        table: 'walk_locations',
        event: PostgresChangeEvent.insert,
        onData: _noOpCallback,
      );

      manager.subscribe();
      manager.dispose();

      verify(() => mockChannel.unsubscribe()).called(1);
    });

    test('subscribe is no-op after dispose', () {
      final manager = RealtimeManager(
        client: mockClient,
        channelName: 'test',
        table: 'walk_locations',
        event: PostgresChangeEvent.insert,
        onData: _noOpCallback,
      );

      manager.dispose();
      manager.subscribe();

      // channel() should never be called since _disposed is true
      verifyNever(() => mockClient.channel(any()));
    });

    test('data callback is not invoked after dispose', () {
      void Function(PostgresChangePayload)? capturedCallback;

      when(() => mockChannel.onPostgresChanges(
            event: any(named: 'event'),
            schema: any(named: 'schema'),
            table: any(named: 'table'),
            filter: any(named: 'filter'),
            callback: any(named: 'callback'),
          )).thenAnswer((invocation) {
        capturedCallback = invocation.namedArguments[#callback]
            as void Function(PostgresChangePayload);
        return mockChannel;
      });

      final receivedPayloads = <PostgresChangePayload>[];
      final manager = RealtimeManager(
        client: mockClient,
        channelName: 'test',
        table: 'walk_locations',
        event: PostgresChangeEvent.insert,
        onData: (payload) => receivedPayloads.add(payload),
      );

      manager.subscribe();
      manager.dispose();

      // Try sending data after dispose
      final mockPayload = MockPostgresChangePayload();
      capturedCallback!(mockPayload);

      expect(receivedPayloads, isEmpty);
    });
  });

  group('RealtimeManager - pet owner receives GPS via Realtime', () {
    test('subscription receives walker location updates', () {
      void Function(PostgresChangePayload)? capturedCallback;

      when(() => mockChannel.onPostgresChanges(
            event: any(named: 'event'),
            schema: any(named: 'schema'),
            table: any(named: 'table'),
            filter: any(named: 'filter'),
            callback: any(named: 'callback'),
          )).thenAnswer((invocation) {
        capturedCallback = invocation.namedArguments[#callback]
            as void Function(PostgresChangePayload);
        return mockChannel;
      });

      final locations = <Map<String, dynamic>>[];
      final manager = RealtimeManager(
        client: mockClient,
        channelName: 'gps_booking_123',
        table: 'walk_locations',
        event: PostgresChangeEvent.insert,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'booking_id',
          value: 'booking-123',
        ),
        onData: (payload) {
          locations.add(payload.newRecord);
        },
      );

      manager.subscribe();

      // Simulate 3 GPS location updates from walker
      for (final loc in [
        {'lat': 19.43, 'lng': -99.13},
        {'lat': 19.44, 'lng': -99.14},
        {'lat': 19.45, 'lng': -99.15},
      ]) {
        final payload = MockPostgresChangePayload();
        when(() => payload.newRecord).thenReturn(loc);
        capturedCallback!(payload);
      }

      expect(locations, hasLength(3));
      expect(locations[0]['lat'], 19.43);
      expect(locations[1]['lat'], 19.44);
      expect(locations[2]['lat'], 19.45);
      manager.dispose();
    });
  });
}

class MockPostgresChangePayload extends Mock
    implements PostgresChangePayload {}
