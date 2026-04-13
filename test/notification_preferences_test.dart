import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/screens/notification_preferences_screen.dart';

void main() {
  group('US-023: Notification preferences screen', () {
    group('NotificationPreferencesScreen structure', () {
      testWidgets('shows all four preference toggles', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: NotificationPreferencesScreen(
              client: _FakeSupabaseClient(prefsRow: _defaultPrefs()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Booking Updates'), findsOneWidget);
        expect(find.text('Walk Updates'), findsOneWidget);
        expect(find.text('Chat Messages'), findsOneWidget);
        expect(find.text('Marketing'), findsOneWidget);
      });

      testWidgets('shows descriptive subtitles for each toggle',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: NotificationPreferencesScreen(
              client: _FakeSupabaseClient(prefsRow: _defaultPrefs()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('New requests, confirmations, cancellations'),
          findsOneWidget,
        );
        expect(
          find.text('Walk started, completed, route updates'),
          findsOneWidget,
        );
        expect(
          find.text('New messages from walkers and owners'),
          findsOneWidget,
        );
        expect(
          find.text('Promotions, tips, and news'),
          findsOneWidget,
        );
      });

      testWidgets('shows loading indicator while fetching', (tester) async {
        final client = _FakeSupabaseClient(
          prefsRow: _defaultPrefs(),
          fetchCompleter: Completer<void>(),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: NotificationPreferencesScreen(client: client),
          ),
        );
        // Don't settle — should still be loading
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Complete the fetch so the timer clears
        client.fetchCompleter!.complete();
        await tester.pumpAndSettle();
      });

      testWidgets('shows error state with retry button on fetch failure',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: NotificationPreferencesScreen(
              client: _FakeSupabaseClient(shouldFail: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Failed to load preferences'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('retry button refetches preferences', (tester) async {
        final client = _FakeSupabaseClient(shouldFail: true);
        await tester.pumpWidget(
          MaterialApp(
            home: NotificationPreferencesScreen(client: client),
          ),
        );
        await tester.pumpAndSettle();

        // Now make it succeed on retry
        client.shouldFail = false;
        client.prefsRow = _defaultPrefs();

        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.text('Booking Updates'), findsOneWidget);
      });
    });

    group('Default values', () {
      testWidgets(
          'on first visit (no row), booking/walk/chat true, marketing false',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: NotificationPreferencesScreen(
              client: _FakeSupabaseClient(prefsRow: null),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // All SwitchListTile widgets
        final switches = tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .toList();
        expect(switches.length, 4);

        // booking_updates, walk_updates, chat_messages = true
        expect(switches[0].value, true); // Booking Updates
        expect(switches[1].value, true); // Walk Updates
        expect(switches[2].value, true); // Chat Messages
        expect(switches[3].value, false); // Marketing
      });
    });

    group('Toggle persistence', () {
      testWidgets('toggling a switch calls update on the client',
          (tester) async {
        final client = _FakeSupabaseClient(prefsRow: _defaultPrefs());
        await tester.pumpWidget(
          MaterialApp(
            home: NotificationPreferencesScreen(client: client),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the Booking Updates switch to toggle it off
        await tester.tap(find.byType(SwitchListTile).first);
        await tester.pumpAndSettle();

        expect(client.lastUpdateColumn, 'booking_updates');
        expect(client.lastUpdateValue, false);
      });
    });

    group('Navigation', () {
      testWidgets('screen has an AppBar with Notifications title',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: NotificationPreferencesScreen(
              client: _FakeSupabaseClient(prefsRow: _defaultPrefs()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Notifications'), findsOneWidget);
      });
    });
  });
}

Map<String, dynamic> _defaultPrefs() => {
      'booking_updates': true,
      'walk_updates': true,
      'chat_messages': true,
      'marketing': false,
    };

/// A fake Supabase client interface that the screen can use for testing
/// without requiring real Supabase dependencies.
class _FakeSupabaseClient implements NotificationPrefsClient {
  Map<String, dynamic>? prefsRow;
  bool shouldFail;
  Completer<void>? fetchCompleter;

  String? lastUpdateColumn;
  bool? lastUpdateValue;

  _FakeSupabaseClient({
    this.prefsRow,
    this.shouldFail = false,
    this.fetchCompleter,
  });

  @override
  Future<Map<String, dynamic>?> fetchPreferences() async {
    if (fetchCompleter != null) {
      await fetchCompleter!.future;
    }
    if (shouldFail) {
      throw Exception('Network error');
    }
    return prefsRow;
  }

  @override
  Future<void> upsertDefaults() async {
    prefsRow = _defaultPrefs();
  }

  @override
  Future<void> updatePreference(String column, bool value) async {
    if (shouldFail) {
      throw Exception('Network error');
    }
    lastUpdateColumn = column;
    lastUpdateValue = value;
    prefsRow?[column] = value;
  }
}
