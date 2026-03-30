import 'dart:async';
import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/models/mock_data.dart';

/// Service that manages Realtime GPS subscriptions for walk tracking.
///
/// Subscribes to the `walk_locations` table filtered by booking_id and
/// exposes a stream of [WalkLocation] updates plus connection status.
class TrackingService {
  TrackingService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  RealtimeChannel? _channel;
  Timer? _pollTimer;

  final _locationController = StreamController<WalkLocation>.broadcast();
  final _connectionController = StreamController<TrackingConnectionState>.broadcast();

  /// Stream of incoming GPS locations.
  Stream<WalkLocation> get locationStream => _locationController.stream;

  /// Stream of connection state changes.
  Stream<TrackingConnectionState> get connectionStream =>
      _connectionController.stream;

  TrackingConnectionState _connectionState = TrackingConnectionState.disconnected;
  TrackingConnectionState get connectionState => _connectionState;

  static void _log(String msg) =>
      developer.log(msg, name: 'TrackingService');

  /// Fetch existing walk locations for a booking (initial load).
  Future<List<WalkLocation>> fetchLocations(String bookingId) async {
    final data = await _client
        .from('walk_locations')
        .select()
        .eq('booking_id', bookingId)
        .order('recorded_at', ascending: true);
    return (data as List)
        .map((row) => WalkLocation.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Subscribe to live GPS updates for a booking.
  void subscribe(String bookingId) {
    _updateConnectionState(TrackingConnectionState.connecting);

    final channelName = 'walk_locations:$bookingId';
    _channel = _client.channel(channelName);

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'walk_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'booking_id',
            value: bookingId,
          ),
          callback: (payload) {
            _log('GPS update received: ${payload.newRecord}');
            try {
              final location =
                  WalkLocation.fromJson(payload.newRecord);
              _locationController.add(location);
            } catch (e) {
              _log('Error parsing GPS update: $e');
            }
          },
        )
        .subscribe((status, [error]) {
      _log('Channel status: $status, error: $error');
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          _updateConnectionState(TrackingConnectionState.connected);
          _stopPolling();
          break;
        case RealtimeSubscribeStatus.closed:
          _updateConnectionState(TrackingConnectionState.disconnected);
          _startPolling(bookingId);
          break;
        case RealtimeSubscribeStatus.channelError:
          _updateConnectionState(TrackingConnectionState.error);
          _startPolling(bookingId);
          break;
        case RealtimeSubscribeStatus.timedOut:
          _updateConnectionState(TrackingConnectionState.error);
          _startPolling(bookingId);
          break;
      }
    });
  }

  /// Fallback polling when Realtime subscription drops.
  void _startPolling(String bookingId) {
    _stopPolling();
    _log('Starting REST fallback polling');
    DateTime? lastSeen;

    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        var query = _client
            .from('walk_locations')
            .select()
            .eq('booking_id', bookingId)
            .order('recorded_at', ascending: false)
            .limit(1);

        final data = await query;
        if (data.isNotEmpty) {
          final location =
              WalkLocation.fromJson(data[0]);
          if (lastSeen == null ||
              location.recordedAt.isAfter(lastSeen!)) {
            lastSeen = location.recordedAt;
            _locationController.add(location);
          }
        }
      } catch (e) {
        _log('Polling error: $e');
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _updateConnectionState(TrackingConnectionState state) {
    _connectionState = state;
    _connectionController.add(state);
  }

  /// Unsubscribe and clean up all resources.
  void dispose() {
    _stopPolling();
    if (_channel != null) {
      _client.removeChannel(_channel!);
      _channel = null;
    }
    _locationController.close();
    _connectionController.close();
  }
}

/// Connection state for the tracking subscription.
enum TrackingConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}
