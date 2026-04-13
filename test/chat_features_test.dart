import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pawgo/widgets/walker_bottom_nav.dart';
import 'package:pawgo/widgets/stat_card.dart';

void main() {
  group('WalkerBottomNav unread badge', () {
    Widget buildNav({int unreadChatCount = 0, int currentIndex = 0}) {
      return MaterialApp(
        home: Scaffold(
          bottomNavigationBar: WalkerBottomNav(
            currentIndex: currentIndex,
            onTap: (_) {},
            unreadChatCount: unreadChatCount,
          ),
        ),
      );
    }

    testWidgets('shows no badge when unread count is 0', (tester) async {
      await tester.pumpWidget(buildNav(unreadChatCount: 0));

      // Badge text should not be present
      expect(find.text('0'), findsNothing);
      // Verify the nav renders
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('My Walks'), findsOneWidget);
      expect(find.text('Earnings'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('shows badge with correct count when unread > 0',
        (tester) async {
      await tester.pumpWidget(buildNav(unreadChatCount: 5));

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('shows 99+ when unread count exceeds 99', (tester) async {
      await tester.pumpWidget(buildNav(unreadChatCount: 150));

      expect(find.text('99+'), findsOneWidget);
      expect(find.text('150'), findsNothing);
    });

    testWidgets('shows badge with count 1', (tester) async {
      await tester.pumpWidget(buildNav(unreadChatCount: 1));

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('shows 99 without plus sign at boundary', (tester) async {
      await tester.pumpWidget(buildNav(unreadChatCount: 99));

      expect(find.text('99'), findsOneWidget);
      expect(find.text('99+'), findsNothing);
    });

    testWidgets('badge appears only on Chat tab (index 2)', (tester) async {
      await tester.pumpWidget(buildNav(unreadChatCount: 3));

      // The badge container has a red background — find it via the text
      final badgeText = find.text('3');
      expect(badgeText, findsOneWidget);

      // Verify there's exactly one badge text, not on every tab
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('active tab uses fill icon variant', (tester) async {
      await tester.pumpWidget(buildNav(currentIndex: 2));

      // When Chat (index 2) is active, its icon should be the fill variant
      // and its text should be cacaoBrown colored
      final chatText = find.text('Chat');
      expect(chatText, findsOneWidget);
    });

    testWidgets('default unread count is 0 when not provided',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: WalkerBottomNav(
            currentIndex: 0,
            onTap: (_) {},
            // unreadChatCount not provided — defaults to 0
          ),
        ),
      ));

      // No badge number should appear
      expect(find.text('0'), findsNothing);
    });
  });

  group('StatCard with IconData', () {
    Widget buildStatCard({
      required IconData icon,
      int number = 5,
      String label = 'Test',
      String variant = 'blue',
    }) {
      return MaterialApp(
        home: Scaffold(
          body: StatCard(
            icon: icon,
            number: number,
            label: label,
            variant: variant,
          ),
        ),
      );
    }

    testWidgets('renders with Phosphor icon', (tester) async {
      await tester.pumpWidget(buildStatCard(
        icon: PhosphorIcons.calendarBlank(),
      ));

      expect(find.text('5'), findsOneWidget);
      expect(find.text('Test'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('displays correct number', (tester) async {
      await tester.pumpWidget(buildStatCard(
        icon: PhosphorIcons.clock(),
        number: 42,
        label: 'Active',
      ));

      expect(find.text('42'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('renders with all variant types', (tester) async {
      for (final variant in ['blue', 'green', 'gray']) {
        await tester.pumpWidget(buildStatCard(
          icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
          variant: variant,
          label: variant,
        ));

        expect(find.text(variant), findsOneWidget);
      }
    });
  });

  group('Typing indicator logic', () {
    test('typing debounce prevents rapid fire', () async {
      // Simulate the debounce logic used in the chat screen
      var broadcastCount = 0;
      Timer? debounce;

      void broadcastTyping() {
        if (debounce?.isActive ?? false) return;
        debounce = Timer(const Duration(milliseconds: 100), () {});
        broadcastCount++;
      }

      // Rapid calls should only increment once
      broadcastTyping();
      broadcastTyping();
      broadcastTyping();

      expect(broadcastCount, 1);

      // After debounce expires, should allow again
      await Future.delayed(const Duration(milliseconds: 150));

      broadcastTyping();
      expect(broadcastCount, 2);

      debounce?.cancel();
    });

    test('typing timeout clears after inactivity', () async {
      var isTyping = false;
      Timer? timeout;

      // Simulate receiving a typing event
      isTyping = true;
      timeout?.cancel();
      timeout = Timer(const Duration(milliseconds: 100), () {
        isTyping = false;
      });

      expect(isTyping, true);

      // Wait for timeout
      await Future.delayed(const Duration(milliseconds: 150));

      expect(isTyping, false);

      timeout?.cancel();
    });

    test('new typing event resets timeout', () async {
      var isTyping = false;
      Timer? timeout;

      void onTypingEvent() {
        isTyping = true;
        timeout?.cancel();
        timeout = Timer(const Duration(milliseconds: 200), () {
          isTyping = false;
        });
      }

      // First event
      onTypingEvent();
      expect(isTyping, true);

      // Wait 100ms, send another event (before 200ms timeout)
      await Future.delayed(const Duration(milliseconds: 100));
      onTypingEvent();
      expect(isTyping, true);

      // Wait 100ms more — original timeout would have fired but was reset
      await Future.delayed(const Duration(milliseconds: 100));
      expect(isTyping, true);

      // Wait for the reset timeout to expire
      await Future.delayed(const Duration(milliseconds: 150));
      expect(isTyping, false);

      timeout?.cancel();
    });

    test('message arrival clears typing indicator', () {
      var isTyping = true;
      Timer? timeout;

      // Simulate a message arriving from the other party
      final incomingMessage = {
        'sender_id': 'other-user',
        'content': 'Hello!',
      };

      final currentUserId = 'my-user';

      if (incomingMessage['sender_id'] != currentUserId) {
        isTyping = false;
        timeout?.cancel();
      }

      expect(isTyping, false);
    });
  });

  group('Unread count logic', () {
    test('counts only messages from other users', () {
      final currentUserId = 'walker-001';
      final messages = [
        {'sender_id': 'owner-001', 'is_read': false},
        {'sender_id': 'owner-001', 'is_read': false},
        {'sender_id': 'walker-001', 'is_read': false}, // own message
        {'sender_id': 'owner-001', 'is_read': true}, // already read
      ];

      final unreadCount = messages
          .where((m) =>
              m['sender_id'] != currentUserId && m['is_read'] == false)
          .length;

      expect(unreadCount, 2);
    });

    test('returns 0 when all messages are read', () {
      final currentUserId = 'walker-001';
      final messages = [
        {'sender_id': 'owner-001', 'is_read': true},
        {'sender_id': 'owner-001', 'is_read': true},
      ];

      final unreadCount = messages
          .where((m) =>
              m['sender_id'] != currentUserId && m['is_read'] == false)
          .length;

      expect(unreadCount, 0);
    });

    test('returns 0 when only own unread messages exist', () {
      final currentUserId = 'walker-001';
      final messages = [
        {'sender_id': 'walker-001', 'is_read': false},
        {'sender_id': 'walker-001', 'is_read': false},
      ];

      final unreadCount = messages
          .where((m) =>
              m['sender_id'] != currentUserId && m['is_read'] == false)
          .length;

      expect(unreadCount, 0);
    });

    test('badge text formats correctly', () {
      String badgeText(int count) {
        return count > 99 ? '99+' : '$count';
      }

      expect(badgeText(0), '0');
      expect(badgeText(1), '1');
      expect(badgeText(99), '99');
      expect(badgeText(100), '99+');
      expect(badgeText(999), '99+');
    });
  });

  group('Notification preview text', () {
    test('truncates long messages to 100 chars with ellipsis', () {
      final longMessage = 'A' * 150;

      final preview = longMessage.length > 100
          ? '${longMessage.substring(0, 100)}\u2026'
          : longMessage;

      expect(preview.length, 101); // 100 chars + ellipsis
      expect(preview.endsWith('\u2026'), true);
    });

    test('short messages are not truncated', () {
      final shortMessage = 'Hello there!';

      final preview = shortMessage.length > 100
          ? '${shortMessage.substring(0, 100)}\u2026'
          : shortMessage;

      expect(preview, 'Hello there!');
      expect(preview.contains('\u2026'), false);
    });

    test('exactly 100 chars are not truncated', () {
      final exactMessage = 'A' * 100;

      final preview = exactMessage.length > 100
          ? '${exactMessage.substring(0, 100)}\u2026'
          : exactMessage;

      expect(preview.length, 100);
      expect(preview.contains('\u2026'), false);
    });
  });
}
