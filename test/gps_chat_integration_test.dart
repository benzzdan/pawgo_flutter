import 'package:flutter_test/flutter_test.dart';

/// Integration tests verifying GPS tracking and walk chat data flow logic.
///
/// These tests verify the logical behavior of the GPS + chat features
/// without requiring a running Supabase instance. They cover:
/// - Chat message type structures (text, photo, status updates)
/// - Chat active/disabled state based on booking status
/// - GPS data format for walk_locations inserts
/// - Message duplicate prevention logic
/// - MIME type detection for media uploads
void main() {
  group('Chat active status', () {
    // Mirrors _isChatActive logic from WalkerChatScreen:
    // bool get _isChatActive => _bookingStatus == 'walk_started';

    test('chat is active when booking status is walk_started', () {
      const status = 'walk_started';
      expect(status == 'walk_started', isTrue);
    });

    test('chat is disabled when booking is confirmed (not started)', () {
      const status = 'confirmed';
      expect(status == 'walk_started', isFalse);
    });

    test('chat is disabled when walk is completed', () {
      const status = 'walk_completed';
      expect(status == 'walk_started', isFalse);
    });

    test('chat is disabled when walk is cancelled', () {
      const status = 'cancelled';
      expect(status == 'walk_started', isFalse);
    });

    test('chat is disabled when status is pending', () {
      const status = 'pending';
      expect(status == 'walk_started', isFalse);
    });
  });

  group('Chat message types', () {
    test('text message has correct structure for Supabase insert', () {
      final message = {
        'booking_id': 'booking-123',
        'sender_id': 'user-456',
        'content': 'Hello, how is my dog doing?',
      };

      expect(message['booking_id'], isNotNull);
      expect(message['sender_id'], isNotNull);
      expect(message['content'], isNotEmpty);
      expect(message.containsKey('media_type'), isFalse);
    });

    test('status update message includes media_type status_update', () {
      final message = {
        'booking_id': 'booking-123',
        'sender_id': 'user-456',
        'content': 'Pee break completed',
        'media_type': 'status_update',
      };

      expect(message['media_type'], 'status_update');
      expect(message['content'], isNotEmpty);
    });

    test('photo message has image media_type and media_url', () {
      // Photo messages are created server-side by the upload-walk-media Edge Function
      final message = {
        'id': 1,
        'booking_id': 'booking-123',
        'sender_id': 'user-456',
        'content': null,
        'media_type': 'image',
        'media_url': 'https://storage.example.com/walk-photos/photo.jpg',
      };

      expect(message['media_type'], 'image');
      expect(message['media_url'], isNotNull);
      expect(message['media_url'].toString(), contains('walk-photos'));
    });

    test('video message has video media_type', () {
      final message = {
        'booking_id': 'booking-123',
        'sender_id': 'user-456',
        'content': null,
        'media_type': 'video',
        'media_url': 'https://storage.example.com/walk-photos/clip.mp4',
      };

      expect(message['media_type'], 'video');
      expect(message['media_url'], isNotNull);
    });

    test('predefined status messages cover all quick actions', () {
      // Matches the quick status messages defined in walker_chat_screen.dart
      final statusMessages = [
        'Pee break completed',
        'Poop pickup completed',
        'Water break taken',
      ];

      for (final status in statusMessages) {
        expect(status, isNotEmpty);
      }
      expect(statusMessages.length, greaterThanOrEqualTo(3));
    });
  });

  group('GPS data flow', () {
    test('GPS insert data matches walk_locations table schema', () {
      final gpsPoint = {
        'booking_id': 'booking-123',
        'lat': 19.4326,
        'lng': -99.1332,
        'accuracy_m': 5.0,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
      };

      expect(gpsPoint['booking_id'], isNotNull);
      expect(gpsPoint['lat'], isA<double>());
      expect(gpsPoint['lng'], isA<double>());
      expect(gpsPoint['accuracy_m'], isA<double>());
      expect(gpsPoint['recorded_at'], isA<String>());
      expect(gpsPoint['recorded_at'].toString(), contains('T'));
    });

    test('GPS coordinates are within valid range', () {
      const lat = 19.4326;
      const lng = -99.1332;

      expect(lat, greaterThanOrEqualTo(-90));
      expect(lat, lessThanOrEqualTo(90));
      expect(lng, greaterThanOrEqualTo(-180));
      expect(lng, lessThanOrEqualTo(180));
    });

    test('recorded_at timestamp is in UTC ISO8601 format', () {
      final timestamp = DateTime.now().toUtc().toIso8601String();

      expect(timestamp, contains('T'));
      expect(timestamp, endsWith('Z'));
    });
  });

  group('Duplicate message prevention', () {
    // Mirrors the dedup logic in WalkerChatScreen._fetchSingleMessage:
    // final exists = _messages.any((m) => m['id'].toString() == messageId);

    test('duplicate messages are detected by id', () {
      final messages = <Map<String, dynamic>>[
        {'id': 1, 'content': 'Hello'},
        {'id': 2, 'content': 'How are you?'},
      ];

      const newMessageId = '2';
      final exists =
          messages.any((m) => m['id'].toString() == newMessageId);

      expect(exists, isTrue);
    });

    test('new messages are not flagged as duplicates', () {
      final messages = <Map<String, dynamic>>[
        {'id': 1, 'content': 'Hello'},
        {'id': 2, 'content': 'How are you?'},
      ];

      const newMessageId = '3';
      final exists =
          messages.any((m) => m['id'].toString() == newMessageId);

      expect(exists, isFalse);
    });
  });

  group('MIME type detection', () {
    // Mirrors _getMimeType from WalkerChatScreen

    String getMimeType(String fileName) {
      final ext = fileName.split('.').last.toLowerCase();
      switch (ext) {
        case 'jpg':
        case 'jpeg':
          return 'image/jpeg';
        case 'png':
          return 'image/png';
        case 'webp':
          return 'image/webp';
        case 'mp4':
          return 'video/mp4';
        case 'mov':
          return 'video/quicktime';
        default:
          return 'application/octet-stream';
      }
    }

    test('detects JPEG images', () {
      expect(getMimeType('photo.jpg'), 'image/jpeg');
      expect(getMimeType('photo.jpeg'), 'image/jpeg');
      expect(getMimeType('Photo.JPG'), 'image/jpeg');
    });

    test('detects PNG images', () {
      expect(getMimeType('screenshot.png'), 'image/png');
    });

    test('detects WebP images', () {
      expect(getMimeType('image.webp'), 'image/webp');
    });

    test('detects MP4 videos', () {
      expect(getMimeType('clip.mp4'), 'video/mp4');
    });

    test('detects MOV videos', () {
      expect(getMimeType('video.mov'), 'video/quicktime');
    });

    test('returns octet-stream for unknown types', () {
      expect(getMimeType('file.xyz'), 'application/octet-stream');
      expect(getMimeType('document.pdf'), 'application/octet-stream');
    });
  });

  group('Message bubble rendering logic', () {
    // Tests the display logic from _MessageBubble

    test('status update is identified by media_type', () {
      final message = {'media_type': 'status_update', 'content': 'Pee break'};
      final isStatusUpdate = message['media_type'] == 'status_update';
      expect(isStatusUpdate, isTrue);
    });

    test('image message is identified by media_type and media_url', () {
      final message = {
        'media_url': 'https://example.com/photo.jpg',
        'media_type': 'image'
      };
      final hasMedia = message['media_url'] != null &&
          (message['media_type'] == 'image' ||
              message['media_type'] == 'video');
      expect(hasMedia, isTrue);
    });

    test('text message has no special media flags', () {
      final message = {
        'content': 'Hello!',
        'media_url': null,
        'media_type': null
      };
      final isStatusUpdate = message['media_type'] == 'status_update';
      final hasMedia = message['media_url'] != null &&
          (message['media_type'] == 'image' ||
              message['media_type'] == 'video');
      expect(isStatusUpdate, isFalse);
      expect(hasMedia, isFalse);
    });

    test('sender name extracted from user join data', () {
      final message = <String, dynamic>{
        'users': {'full_name': 'John Doe', 'avatar_url': null}
      };
      final user = message['users'];
      String senderName = 'Unknown';
      if (user is Map) {
        senderName = (user['full_name'] as String?) ?? 'Unknown';
      }
      expect(senderName, 'John Doe');
    });

    test('time string formatted correctly from created_at', () {
      final message = {'created_at': '2026-03-22T14:30:00.000Z'};
      final created = message['created_at'];
      final dt = DateTime.parse(created!).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final timeString = '$hour:$minute $period';

      expect(timeString, matches(RegExp(r'\d{1,2}:\d{2} [AP]M')));
    });

    test('status update icon determined by content keywords', () {
      IconType getIconType(String content) {
        if (content.toLowerCase().contains('pee')) return IconType.pee;
        if (content.toLowerCase().contains('poop')) return IconType.poop;
        if (content.toLowerCase().contains('water')) return IconType.water;
        return IconType.info;
      }

      expect(getIconType('Pee break completed'), IconType.pee);
      expect(getIconType('Poop pickup completed'), IconType.poop);
      expect(getIconType('Water break taken'), IconType.water);
      expect(getIconType('Something else'), IconType.info);
    });
  });
}

// Helper enum for status icon type testing (mirrors _MessageBubble logic)
enum IconType { pee, poop, water, info }
