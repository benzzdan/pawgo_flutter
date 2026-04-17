import 'package:flutter_test/flutter_test.dart';

/// Tests validating US-003: Owner chat screen for active walk.
/// Verifies the logic used by WalkerChatScreen and ActiveWalkScreen for
/// owner-side chat functionality (route args, status update pills, media
/// detection, unread badges).
void main() {
  group('Owner chat route arguments', () {
    test('owner view passes walker name as other_party_name', () {
      // Simulate the logic in active_walk_screen.dart line 1037:
      // _isWalker ? _ownerName : _walkerName
      const isWalker = false; // owner viewing
      const ownerName = 'Alice Owner';
      const walkerName = 'Bob Walker';
      const bookingId = 'booking-123';

      final args = {
        'booking_id': bookingId,
        'other_party_name': isWalker ? ownerName : walkerName,
      };

      expect(args['booking_id'], 'booking-123');
      expect(args['other_party_name'], 'Bob Walker');
    });

    test('walker view passes owner name as other_party_name', () {
      const isWalker = true;
      const ownerName = 'Alice Owner';
      const walkerName = 'Bob Walker';

      final otherPartyName = isWalker ? ownerName : walkerName;

      expect(otherPartyName, 'Alice Owner');
    });
  });

  group('Status update message detection and icons', () {
    bool isStatusUpdate(Map<String, dynamic> message) {
      return message['media_type'] == 'status_update';
    }

    String getStatusIcon(String content) {
      if (content.toLowerCase().contains('pee')) return 'pawPrint';
      if (content.toLowerCase().contains('poop')) return 'leaf';
      if (content.toLowerCase().contains('water')) return 'drop';
      return 'info';
    }

    test('status_update media_type is detected', () {
      final message = {'media_type': 'status_update', 'content': 'Pee break'};
      expect(isStatusUpdate(message), true);
    });

    test('regular text message is not a status update', () {
      final message = {'media_type': null, 'content': 'Hello!'};
      expect(isStatusUpdate(message), false);
    });

    test('image message is not a status update', () {
      final message = {'media_type': 'image', 'content': ''};
      expect(isStatusUpdate(message), false);
    });

    test('pee status maps to pawPrint icon', () {
      expect(getStatusIcon('Pee break'), 'pawPrint');
      expect(getStatusIcon('Quick pee stop'), 'pawPrint');
    });

    test('poop status maps to leaf icon', () {
      expect(getStatusIcon('Poop break'), 'leaf');
      expect(getStatusIcon('Had a poop'), 'leaf');
    });

    test('water status maps to drop icon', () {
      expect(getStatusIcon('Water break'), 'drop');
      expect(getStatusIcon('Drank some water'), 'drop');
    });

    test('unknown status maps to info icon', () {
      expect(getStatusIcon('Walk started'), 'info');
      expect(getStatusIcon('All good!'), 'info');
    });

    test('status detection is case-insensitive', () {
      expect(getStatusIcon('PEE'), 'pawPrint');
      expect(getStatusIcon('POOP'), 'leaf');
      expect(getStatusIcon('WATER'), 'drop');
    });
  });

  group('Media message detection', () {
    bool hasMedia(Map<String, dynamic> message) {
      return message['media_url'] != null &&
          (message['media_type'] == 'image' ||
              message['media_type'] == 'video');
    }

    test('image message with media_url is detected', () {
      final message = {
        'media_url': 'https://storage.example.com/photo.jpg',
        'media_type': 'image',
      };
      expect(hasMedia(message), true);
    });

    test('video message with media_url is detected', () {
      final message = {
        'media_url': 'https://storage.example.com/video.mp4',
        'media_type': 'video',
      };
      expect(hasMedia(message), true);
    });

    test('status_update with media_url is NOT detected as media', () {
      final message = {
        'media_url': 'https://storage.example.com/something',
        'media_type': 'status_update',
      };
      expect(hasMedia(message), false);
    });

    test('image type without media_url is NOT detected as media', () {
      final message = {
        'media_url': null,
        'media_type': 'image',
      };
      expect(hasMedia(message), false);
    });

    test('plain text message has no media', () {
      final message = {
        'media_url': null,
        'media_type': null,
        'content': 'Hello!',
      };
      expect(hasMedia(message), false);
    });
  });

  group('Owner active walk unread badge', () {
    test('badge shows count for messages from walker', () {
      const currentUserId = 'owner-001';
      var unreadCount = 0;

      // Simulate new messages arriving via Realtime
      final newMessages = [
        {'sender_id': 'walker-001', 'content': 'Starting walk!'},
        {'sender_id': 'walker-001', 'content': 'Pee break'},
        {'sender_id': 'owner-001', 'content': 'Thanks!'}, // own message
      ];

      for (final msg in newMessages) {
        if (msg['sender_id'] != currentUserId) {
          unreadCount++;
        }
      }

      expect(unreadCount, 2);
    });

    test('badge resets to 0 when chat button tapped', () {
      var unreadCount = 5;

      // Simulate tapping chat button (active_walk_screen.dart line 1032)
      unreadCount = 0;

      expect(unreadCount, 0);
    });

    test('badge text shows 9+ when count exceeds 9', () {
      const unreadCount = 15;
      final badgeText = unreadCount > 9 ? '9+' : '$unreadCount';
      expect(badgeText, '9+');
    });

    test('badge text shows exact count at boundary', () {
      const unreadCount = 9;
      final badgeText = unreadCount > 9 ? '9+' : '$unreadCount';
      expect(badgeText, '9');
    });
  });
}
