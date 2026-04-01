import 'dart:async';
import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

/// A realtime booking status update from the `bookings` table.
class BookingStatusUpdate {
  final String bookingId;
  final String newStatus;
  final String? startedAt;
  final String? completedAt;

  const BookingStatusUpdate({
    required this.bookingId,
    required this.newStatus,
    this.startedAt,
    this.completedAt,
  });

  factory BookingStatusUpdate.fromRecord(Map<String, dynamic> record) {
    return BookingStatusUpdate(
      bookingId: record['id'] as String,
      newStatus: record['status'] as String,
      startedAt: record['started_at'] as String?,
      completedAt: record['completed_at'] as String?,
    );
  }
}

/// Connection state for the booking status Realtime subscription.
enum BookingStatusConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Service that subscribes to booking status changes via Supabase Realtime.
///
/// Follows the same pattern as [ChatService] and [TrackingService]:
/// Realtime channel with REST fallback polling every 10 s on disconnect.
class BookingStatusService {
  BookingStatusService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  RealtimeChannel? _channel;
  Timer? _pollTimer;

  final _statusController =
      StreamController<BookingStatusUpdate>.broadcast();
  final _connectionController =
      StreamController<BookingStatusConnectionState>.broadcast();

  /// Stream of booking status updates (UPDATE events only).
  Stream<BookingStatusUpdate> get statusStream => _statusController.stream;

  /// Stream of connection state changes.
  Stream<BookingStatusConnectionState> get connectionStream =>
      _connectionController.stream;

  BookingStatusConnectionState _connectionState =
      BookingStatusConnectionState.disconnected;
  BookingStatusConnectionState get connectionState => _connectionState;

  /// The column and value used for filtering (e.g., owner_id or booking id).
  String? _filterColumn;
  String? _filterValue;

  static void _log(String msg) =>
      developer.log(msg, name: 'BookingStatusService');

  /// Subscribe to status changes for all bookings matching a filter.
  ///
  /// [filterColumn] is the column to filter on (e.g., 'owner_id').
  /// [filterValue] is the value to match.
  void subscribe({
    required String filterColumn,
    required String filterValue,
  }) {
    _filterColumn = filterColumn;
    _filterValue = filterValue;
    _updateConnectionState(BookingStatusConnectionState.connecting);

    final channelName = 'bookings_status:$filterColumn:$filterValue';
    _channel = _client.channel(channelName);

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: filterColumn,
            value: filterValue,
          ),
          callback: (payload) {
            _log('Booking status update: ${payload.newRecord}');
            try {
              final update =
                  BookingStatusUpdate.fromRecord(payload.newRecord);
              _statusController.add(update);
            } catch (e) {
              _log('Error parsing booking status update: $e');
            }
          },
        )
        .subscribe((status, [error]) {
      _log('Channel status: $status, error: $error');
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          _updateConnectionState(BookingStatusConnectionState.connected);
          _stopPolling();
          break;
        case RealtimeSubscribeStatus.closed:
          _updateConnectionState(
              BookingStatusConnectionState.disconnected);
          _startPolling();
          break;
        case RealtimeSubscribeStatus.channelError:
          _updateConnectionState(BookingStatusConnectionState.error);
          _startPolling();
          break;
        case RealtimeSubscribeStatus.timedOut:
          _updateConnectionState(BookingStatusConnectionState.error);
          _startPolling();
          break;
      }
    });
  }

  /// Subscribe to status changes for a single booking by ID.
  void subscribeToBooking(String bookingId) {
    subscribe(filterColumn: 'id', filterValue: bookingId);
  }

  /// Fallback REST polling when Realtime subscription drops.
  void _startPolling() {
    if (_filterColumn == null || _filterValue == null) return;
    _stopPolling();
    _log('Starting REST fallback polling');

    // Track last known statuses to detect changes
    final Map<String, String> lastKnownStatuses = {};

    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final data = await _client
            .from('bookings')
            .select('id, status, started_at, completed_at')
            .eq(_filterColumn!, _filterValue!);
        for (final row in data) {
          final id = row['id'] as String;
          final status = row['status'] as String;
          final lastStatus = lastKnownStatuses[id];
          if (lastStatus != null && lastStatus != status) {
            _statusController.add(BookingStatusUpdate.fromRecord(row));
          }
          lastKnownStatuses[id] = status;
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

  void _updateConnectionState(BookingStatusConnectionState state) {
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
    _statusController.close();
    _connectionController.close();
  }
}
