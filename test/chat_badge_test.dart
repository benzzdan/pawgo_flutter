import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/services/chat_presence_tracker.dart';

/// Tests for US-010: Chat badge suppressed while on chat screen.
///
/// The ChatPresenceTracker tracks which booking's chat is currently open.
/// Parent screens (ActiveWalkScreen, WalkerChatListScreen) check this
/// before incrementing unread badge counts.
void main() {
  setUp(() {
    // Ensure clean state before each test
    ChatPresenceTracker.clear();
  });

  group('US-010: Chat badge suppressed while on chat screen', () {
    group('Badge count is 0 when chat screen opens', () {
      test('enterChat marks the booking as active', () {
        const bookingId = 'booking-001';

        ChatPresenceTracker.enterChat(bookingId);

        expect(ChatPresenceTracker.isOnChat(bookingId), true);
      });

      test('badge increment is suppressed while chat is active', () {
        const bookingId = 'booking-001';
        var unreadCount = 3; // Existing unread count

        // User opens chat screen
        ChatPresenceTracker.enterChat(bookingId);

        // Simulate: on chat open, reset badge to 0
        if (ChatPresenceTracker.isOnChat(bookingId)) {
          unreadCount = 0;
        }

        expect(unreadCount, 0);
      });
    });

    group('Messages arriving while chat is open do not increment badge', () {
      test('new message from other user does NOT increment badge when on chat', () {
        const bookingId = 'booking-001';
        const currentUserId = 'owner-001';
        var unreadCount = 0;

        ChatPresenceTracker.enterChat(bookingId);

        // Simulate realtime messages arriving
        final incomingMessages = [
          {'sender_id': 'walker-001', 'content': 'Starting walk!'},
          {'sender_id': 'walker-001', 'content': 'Pee break'},
          {'sender_id': 'walker-001', 'content': 'All good'},
        ];

        for (final msg in incomingMessages) {
          if (msg['sender_id'] != currentUserId &&
              !ChatPresenceTracker.isOnChat(bookingId)) {
            unreadCount++;
          }
        }

        expect(unreadCount, 0, reason: 'Badge should not increment while chat is open');
      });

      test('isOnChat returns false for a different booking', () {
        ChatPresenceTracker.enterChat('booking-001');

        expect(ChatPresenceTracker.isOnChat('booking-002'), false,
            reason: 'Only the active booking should be tracked');
      });
    });

    group('After navigating away, new messages increment badge normally', () {
      test('leaveChat marks the booking as inactive', () {
        const bookingId = 'booking-001';

        ChatPresenceTracker.enterChat(bookingId);
        expect(ChatPresenceTracker.isOnChat(bookingId), true);

        ChatPresenceTracker.leaveChat(bookingId);
        expect(ChatPresenceTracker.isOnChat(bookingId), false);
      });

      test('messages arriving after leaving chat DO increment badge', () {
        const bookingId = 'booking-001';
        const currentUserId = 'owner-001';
        var unreadCount = 0;

        // Open and close chat
        ChatPresenceTracker.enterChat(bookingId);
        ChatPresenceTracker.leaveChat(bookingId);

        // New messages arrive after leaving
        final incomingMessages = [
          {'sender_id': 'walker-001', 'content': 'Photo sent'},
          {'sender_id': 'walker-001', 'content': 'Almost done'},
        ];

        for (final msg in incomingMessages) {
          if (msg['sender_id'] != currentUserId &&
              !ChatPresenceTracker.isOnChat(bookingId)) {
            unreadCount++;
          }
        }

        expect(unreadCount, 2, reason: 'Badge should increment after leaving chat');
      });

      test('full lifecycle: enter, receive messages, leave, receive more', () {
        const bookingId = 'booking-001';
        const currentUserId = 'owner-001';
        var unreadCount = 0;

        // Phase 1: Messages before opening chat (badge should increment)
        void receiveMessage(String senderId) {
          if (senderId != currentUserId &&
              !ChatPresenceTracker.isOnChat(bookingId)) {
            unreadCount++;
          }
        }

        receiveMessage('walker-001');
        expect(unreadCount, 1);

        // Phase 2: Open chat, reset badge
        ChatPresenceTracker.enterChat(bookingId);
        unreadCount = 0;

        // Phase 3: Messages while on chat (badge should NOT increment)
        receiveMessage('walker-001');
        receiveMessage('walker-001');
        expect(unreadCount, 0);

        // Phase 4: Leave chat
        ChatPresenceTracker.leaveChat(bookingId);

        // Phase 5: Messages after leaving (badge should increment)
        receiveMessage('walker-001');
        expect(unreadCount, 1);
      });
    });

    group('Edge cases', () {
      test('leaveChat on non-tracked booking is a no-op', () {
        // Should not throw
        ChatPresenceTracker.leaveChat('non-existent');
        expect(ChatPresenceTracker.isOnChat('non-existent'), false);
      });

      test('multiple enterChat calls for same booking are idempotent', () {
        const bookingId = 'booking-001';

        ChatPresenceTracker.enterChat(bookingId);
        ChatPresenceTracker.enterChat(bookingId);

        expect(ChatPresenceTracker.isOnChat(bookingId), true);

        // Single leaveChat should clear it
        ChatPresenceTracker.leaveChat(bookingId);
        expect(ChatPresenceTracker.isOnChat(bookingId), false);
      });

      test('clear resets all tracked bookings', () {
        ChatPresenceTracker.enterChat('booking-001');
        ChatPresenceTracker.enterChat('booking-002');

        ChatPresenceTracker.clear();

        expect(ChatPresenceTracker.isOnChat('booking-001'), false);
        expect(ChatPresenceTracker.isOnChat('booking-002'), false);
      });
    });
  });
}
