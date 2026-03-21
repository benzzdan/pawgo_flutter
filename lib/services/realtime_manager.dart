import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages a Supabase Realtime channel with auto-reconnect and REST polling fallback.
///
/// When the Realtime connection drops, polls the table via REST every 10 seconds
/// until the Realtime channel reconnects.
class RealtimeManager {
  final SupabaseClient _client;
  final String channelName;
  final String table;
  final String schema;
  final PostgresChangeEvent event;
  final PostgresChangeFilter? filter;
  final void Function(PostgresChangePayload payload) onData;
  final VoidCallback? onReconnect;

  /// REST polling configuration.
  final String? pollingOrderColumn;
  final bool pollingAscending;
  final void Function(List<Map<String, dynamic>> rows)? onPollingData;

  RealtimeChannel? _channel;
  Timer? _pollTimer;
  bool _isSubscribed = false;
  bool _disposed = false;
  static const _pollInterval = Duration(seconds: 10);

  RealtimeManager({
    SupabaseClient? client,
    required this.channelName,
    required this.table,
    required this.event,
    required this.onData,
    this.schema = 'public',
    this.filter,
    this.onReconnect,
    this.pollingOrderColumn,
    this.pollingAscending = true,
    this.onPollingData,
  }) : _client = client ?? Supabase.instance.client;

  /// Subscribe to the Realtime channel.
  void subscribe() {
    if (_disposed) return;
    _unsubscribeChannel();

    _channel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: event,
          schema: schema,
          table: table,
          filter: filter,
          callback: (payload) {
            if (_disposed) return;
            // Realtime is working — stop polling
            _stopPolling();
            _isSubscribed = true;
            onData(payload);
          },
        )
        .subscribe((status, [error]) {
      if (_disposed) return;
      if (status == RealtimeSubscribeStatus.subscribed) {
        _isSubscribed = true;
        _stopPolling();
        debugPrint('RealtimeManager[$channelName]: subscribed');
      } else if (status == RealtimeSubscribeStatus.closed ||
          status == RealtimeSubscribeStatus.channelError) {
        debugPrint('RealtimeManager[$channelName]: disconnected ($status)');
        _isSubscribed = false;
        _startPolling();
        // Attempt reconnect after a delay
        _scheduleReconnect();
      }
    });
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    Future.delayed(const Duration(seconds: 5), () {
      if (_disposed || _isSubscribed) return;
      debugPrint('RealtimeManager[$channelName]: attempting reconnect');
      subscribe();
      onReconnect?.call();
    });
  }

  void _startPolling() {
    if (_disposed || _pollTimer != null || onPollingData == null) return;
    debugPrint('RealtimeManager[$channelName]: starting REST polling fallback');
    _poll(); // Immediate first poll
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (_disposed || _isSubscribed) {
      _stopPolling();
      return;
    }
    try {
      var query = _client.from(table).select();

      // Apply filter if available
      if (filter != null && filter!.type == PostgresChangeFilterType.eq) {
        query = query.eq(filter!.column, filter!.value);
      }

      final data = pollingOrderColumn != null
          ? await query.order(pollingOrderColumn!, ascending: pollingAscending)
          : await query;

      if (!_disposed) {
        onPollingData?.call(List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      debugPrint('RealtimeManager[$channelName]: polling error: $e');
    }
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _unsubscribeChannel() {
    _channel?.unsubscribe();
    _channel = null;
    _isSubscribed = false;
  }

  /// Clean up resources.
  void dispose() {
    _disposed = true;
    _stopPolling();
    _unsubscribeChannel();
  }
}
