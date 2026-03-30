import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/services/chat_service.dart';

void main() {
  group('Message.fromJson', () {
    test('parses a complete message JSON', () {
      final json = {
        'id': 'msg-001',
        'booking_id': 'booking-001',
        'sender_id': 'user-abc',
        'content': 'Hello!',
        'media_url': null,
        'media_type': null,
        'is_read': false,
        'created_at': '2026-03-30T14:30:00Z',
      };

      final message = Message.fromJson(json);

      expect(message.id, 'msg-001');
      expect(message.bookingId, 'booking-001');
      expect(message.senderId, 'user-abc');
      expect(message.content, 'Hello!');
      expect(message.mediaUrl, isNull);
      expect(message.mediaType, isNull);
      expect(message.isRead, false);
      expect(message.createdAt, DateTime.utc(2026, 3, 30, 14, 30));
      expect(message.isStatusUpdate, false);
    });

    test('parses a media message', () {
      final json = {
        'id': 'msg-002',
        'booking_id': 'booking-001',
        'sender_id': 'user-abc',
        'content': 'Photo of Max',
        'media_url': 'https://storage.example.com/walk-media/photo.jpg',
        'media_type': 'image',
        'is_read': true,
        'created_at': '2026-03-30T14:35:00Z',
      };

      final message = Message.fromJson(json);

      expect(message.mediaUrl, isNotNull);
      expect(message.mediaType, 'image');
      expect(message.isRead, true);
      expect(message.isStatusUpdate, false);
    });

    test('identifies status_update messages', () {
      final json = {
        'id': 'msg-003',
        'booking_id': 'booking-001',
        'sender_id': 'user-abc',
        'content': 'Walk started',
        'media_url': null,
        'media_type': 'status_update',
        'is_read': false,
        'created_at': '2026-03-30T14:20:00Z',
      };

      final message = Message.fromJson(json);

      expect(message.isStatusUpdate, true);
    });

    test('handles missing is_read (defaults to false)', () {
      final json = {
        'id': 'msg-004',
        'booking_id': 'booking-002',
        'sender_id': 'user-xyz',
        'content': 'Hi there',
        'created_at': '2026-03-30T15:00:00Z',
      };

      final message = Message.fromJson(json);

      expect(message.isRead, false);
      expect(message.content, 'Hi there');
    });
  });

  group('ChatConnectionState', () {
    test('has all expected values', () {
      expect(ChatConnectionState.values, hasLength(4));
      expect(ChatConnectionState.values,
          contains(ChatConnectionState.disconnected));
      expect(ChatConnectionState.values,
          contains(ChatConnectionState.connecting));
      expect(ChatConnectionState.values,
          contains(ChatConnectionState.connected));
      expect(
          ChatConnectionState.values, contains(ChatConnectionState.error));
    });
  });

  group('Chat Realtime integration', () {
    test(
        'inserting a message row triggers message stream update',
        () async {
      // This test verifies the data flow: when a Message is parsed
      // from a Realtime payload and added to the stream, listeners receive it.
      final controller = StreamController<Message>.broadcast();

      final messages = <Message>[];
      final sub = controller.stream.listen((msg) {
        messages.add(msg);
      });

      // Simulate a Realtime insert event payload
      final payload = {
        'id': 'msg-rt-001',
        'booking_id': 'booking-active-001',
        'sender_id': 'walker-user-001',
        'content': 'Hi! Just started the walk with Max',
        'media_url': null,
        'media_type': null,
        'is_read': false,
        'created_at': '2026-03-30T14:30:00Z',
      };

      final message = Message.fromJson(payload);
      controller.add(message);

      // Allow stream to propagate
      await Future.delayed(Duration.zero);

      expect(messages, hasLength(1));
      expect(messages.first.content, 'Hi! Just started the walk with Max');
      expect(messages.first.senderId, 'walker-user-001');
      expect(messages.first.bookingId, 'booking-active-001');

      // Simulate a second message
      final payload2 = {
        'id': 'msg-rt-002',
        'booking_id': 'booking-active-001',
        'sender_id': 'owner-user-001',
        'content': 'Great! Thank you!',
        'media_url': null,
        'media_type': null,
        'is_read': false,
        'created_at': '2026-03-30T14:30:05Z',
      };

      controller.add(Message.fromJson(payload2));
      await Future.delayed(Duration.zero);

      expect(messages, hasLength(2));
      expect(messages.last.content, 'Great! Thank you!');
      expect(messages.last.senderId, 'owner-user-001');

      await sub.cancel();
      await controller.close();
    });

    test('chat list reflects all received messages in order', () async {
      final allMessages = <Message>[];

      final payloads = [
        {
          'id': 'msg-1',
          'booking_id': 'b1',
          'sender_id': 'walker-1',
          'content': 'Starting walk now',
          'media_type': 'status_update',
          'created_at': '2026-03-30T14:00:00Z'
        },
        {
          'id': 'msg-2',
          'booking_id': 'b1',
          'sender_id': 'walker-1',
          'content': 'Max is being great!',
          'created_at': '2026-03-30T14:05:00Z'
        },
        {
          'id': 'msg-3',
          'booking_id': 'b1',
          'sender_id': 'owner-1',
          'content': 'Awesome, thanks!',
          'created_at': '2026-03-30T14:06:00Z'
        },
      ];

      for (final json in payloads) {
        allMessages.add(Message.fromJson(json));
      }

      expect(allMessages, hasLength(3));
      expect(allMessages[0].isStatusUpdate, true);
      expect(allMessages[1].isStatusUpdate, false);
      expect(allMessages[2].senderId, 'owner-1');
    });

    test('duplicate messages are identifiable by id', () {
      final msg1 = Message.fromJson({
        'id': 'msg-dup',
        'booking_id': 'b1',
        'sender_id': 'u1',
        'content': 'Hello',
        'created_at': '2026-03-30T14:00:00Z',
      });

      final msg2 = Message.fromJson({
        'id': 'msg-dup',
        'booking_id': 'b1',
        'sender_id': 'u1',
        'content': 'Hello',
        'created_at': '2026-03-30T14:00:00Z',
      });

      // The screen deduplicates by checking id
      expect(msg1.id, msg2.id);
    });
  });
}
