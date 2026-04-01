import 'dart:async';
import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

/// A single chat message from the `messages` table.
class Message {
  final String id;
  final String bookingId;
  final String senderId;
  final String? content;
  final String? mediaUrl;
  final String? mediaType;
  final bool isRead;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.bookingId,
    required this.senderId,
    this.content,
    this.mediaUrl,
    this.mediaType,
    this.isRead = false,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Whether this is a status update (e.g., walk started/ended) rather than a
  /// user-typed message.
  bool get isStatusUpdate => mediaType == 'status_update';
}

/// Connection state for the chat Realtime subscription.
enum ChatConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Service that manages Realtime chat subscriptions.
///
/// Subscribes to the `messages` table filtered by booking_id and exposes a
/// stream of [Message] updates plus connection status. Falls back to REST
/// polling (every 10 s) when the Realtime channel drops.
class ChatService {
  ChatService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  RealtimeChannel? _channel;
  Timer? _pollTimer;

  final _messageController = StreamController<Message>.broadcast();
  final _connectionController =
      StreamController<ChatConnectionState>.broadcast();

  /// Stream of incoming messages (new inserts only).
  Stream<Message> get messageStream => _messageController.stream;

  /// Stream of connection state changes.
  Stream<ChatConnectionState> get connectionStream =>
      _connectionController.stream;

  ChatConnectionState _connectionState = ChatConnectionState.disconnected;
  ChatConnectionState get connectionState => _connectionState;

  String get _currentUserId => _client.auth.currentUser!.id;

  static void _log(String msg) =>
      developer.log(msg, name: 'ChatService');

  /// Fetch existing messages for a booking (initial load).
  Future<List<Message>> fetchMessages(String bookingId) async {
    final data = await _client
        .from('messages')
        .select()
        .eq('booking_id', bookingId)
        .order('created_at', ascending: true);
    return (data as List)
        .map((row) => Message.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Send a text message for a booking.
  Future<Message> sendMessage(String bookingId, String content) async {
    final data = await _client.from('messages').insert({
      'booking_id': bookingId,
      'sender_id': _currentUserId,
      'content': content,
    }).select().single();
    return Message.fromJson(data);
  }

  /// Subscribe to live message inserts for a booking.
  void subscribe(String bookingId) {
    _updateConnectionState(ChatConnectionState.connecting);

    final channelName = 'messages:$bookingId';
    _channel = _client.channel(channelName);

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'booking_id',
            value: bookingId,
          ),
          callback: (payload) {
            _log('New message received: ${payload.newRecord}');
            try {
              final message = Message.fromJson(payload.newRecord);
              _messageController.add(message);
            } catch (e) {
              _log('Error parsing message: $e');
            }
          },
        )
        .subscribe((status, [error]) {
      _log('Channel status: $status, error: $error');
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          _updateConnectionState(ChatConnectionState.connected);
          _stopPolling();
          break;
        case RealtimeSubscribeStatus.closed:
          _updateConnectionState(ChatConnectionState.disconnected);
          _startPolling(bookingId);
          break;
        case RealtimeSubscribeStatus.channelError:
          _updateConnectionState(ChatConnectionState.error);
          _startPolling(bookingId);
          break;
        case RealtimeSubscribeStatus.timedOut:
          _updateConnectionState(ChatConnectionState.error);
          _startPolling(bookingId);
          break;
      }
    });
  }

  /// Fallback REST polling when Realtime subscription drops.
  void _startPolling(String bookingId) {
    _stopPolling();
    _log('Starting REST fallback polling');
    DateTime? lastSeen;

    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final data = await _client
            .from('messages')
            .select()
            .eq('booking_id', bookingId)
            .order('created_at', ascending: false)
            .limit(1);
        if (data.isNotEmpty) {
          final message = Message.fromJson(data[0]);
          if (lastSeen == null || message.createdAt.isAfter(lastSeen!)) {
            lastSeen = message.createdAt;
            _messageController.add(message);
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

  void _updateConnectionState(ChatConnectionState state) {
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
    _messageController.close();
    _connectionController.close();
  }
}
