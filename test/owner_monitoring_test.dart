import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawgo/screens/active_walk_screen.dart';
import 'package:pawgo/theme/app_theme.dart';

void main() {
  // Prevent Google Fonts from fetching during tests
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('US-015: Owner monitoring presence heartbeat', () {
    // --- OwnerPresenceState determination logic ---
    group('OwnerPresenceState', () {
      test('returns watching when owner_last_seen_at is within 60 seconds', () {
        final now = DateTime.now().toUtc();
        final lastSeen = now.subtract(const Duration(seconds: 30));
        final state = OwnerPresenceState.fromLastSeen(lastSeen, now: now);
        expect(state, OwnerPresenceState.watching);
      });

      test('returns watching when owner_last_seen_at is exactly 60 seconds ago', () {
        final now = DateTime.now().toUtc();
        final lastSeen = now.subtract(const Duration(seconds: 60));
        final state = OwnerPresenceState.fromLastSeen(lastSeen, now: now);
        expect(state, OwnerPresenceState.watching);
      });

      test('returns notWatching when owner_last_seen_at is older than 60 seconds', () {
        final now = DateTime.now().toUtc();
        final lastSeen = now.subtract(const Duration(seconds: 61));
        final state = OwnerPresenceState.fromLastSeen(lastSeen, now: now);
        expect(state, OwnerPresenceState.notWatching);
      });

      test('returns notWatching when owner_last_seen_at is null', () {
        final state = OwnerPresenceState.fromLastSeen(null);
        expect(state, OwnerPresenceState.notWatching);
      });

      test('returns watching when owner_last_seen_at is in the future (clock skew)', () {
        final now = DateTime.now().toUtc();
        final lastSeen = now.add(const Duration(seconds: 5));
        final state = OwnerPresenceState.fromLastSeen(lastSeen, now: now);
        expect(state, OwnerPresenceState.watching);
      });
    });

    // --- OwnerPresenceIndicator widget ---
    group('OwnerPresenceIndicator widget', () {
      testWidgets('shows "Owner is watching" with green dot when watching', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OwnerPresenceIndicator(
                presenceState: OwnerPresenceState.watching,
              ),
            ),
          ),
        );

        expect(find.text('Owner is watching'), findsOneWidget);
        // Verify green dot is present
        final container = tester.widget<Container>(
          find.byWidgetPredicate((w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == AppColors.green500 &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle),
        );
        expect(container, isNotNull);
      });

      testWidgets('shows "Owner is not watching" when notWatching', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OwnerPresenceIndicator(
                presenceState: OwnerPresenceState.notWatching,
              ),
            ),
          ),
        );

        expect(find.text('Owner is not watching'), findsOneWidget);
      });

      testWidgets('has semantic label for accessibility', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OwnerPresenceIndicator(
                presenceState: OwnerPresenceState.watching,
              ),
            ),
          ),
        );

        // Verify Semantics widget wraps the indicator with the correct label
        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Owner is watching',
          ),
        );
        expect(semantics, isNotNull);
      });
    });

    // --- Notification once-per-session flag ---
    group('Owner monitoring notification flag', () {
      test('OwnerHeartbeatManager tracks notified state', () {
        final manager = OwnerHeartbeatManager();
        expect(manager.hasNotifiedWalker, false);
        manager.markNotified();
        expect(manager.hasNotifiedWalker, true);
      });

      test('OwnerHeartbeatManager reset clears notified state', () {
        final manager = OwnerHeartbeatManager();
        manager.markNotified();
        expect(manager.hasNotifiedWalker, true);
        manager.reset();
        expect(manager.hasNotifiedWalker, false);
      });
    });

    // --- Timer lifecycle tests using fake_async ---
    group('OwnerHeartbeatManager timer lifecycle', () {
      test('heartbeat timer fires every 30 seconds', () {
        fakeAsync((async) {
          int heartbeatCount = 0;
          final manager = OwnerHeartbeatManager();
          manager.startHeartbeat(onHeartbeat: () {
            heartbeatCount++;
          });

          // Immediate first heartbeat
          expect(heartbeatCount, 1);

          // Advance 30 seconds — second heartbeat
          async.elapse(const Duration(seconds: 30));
          expect(heartbeatCount, 2);

          // Advance another 30 seconds — third heartbeat
          async.elapse(const Duration(seconds: 30));
          expect(heartbeatCount, 3);

          manager.dispose();
        });
      });

      test('heartbeat timer stops on dispose', () {
        fakeAsync((async) {
          int heartbeatCount = 0;
          final manager = OwnerHeartbeatManager();
          manager.startHeartbeat(onHeartbeat: () {
            heartbeatCount++;
          });

          expect(heartbeatCount, 1); // immediate

          manager.dispose();

          async.elapse(const Duration(seconds: 60));
          expect(heartbeatCount, 1); // no more heartbeats
        });
      });

      test('heartbeat timer pauses and resumes', () {
        fakeAsync((async) {
          int heartbeatCount = 0;
          final manager = OwnerHeartbeatManager();
          manager.startHeartbeat(onHeartbeat: () {
            heartbeatCount++;
          });

          expect(heartbeatCount, 1); // immediate

          // Pause
          manager.pause();
          async.elapse(const Duration(seconds: 60));
          expect(heartbeatCount, 1); // no heartbeats while paused

          // Resume — should fire immediate heartbeat on resume
          manager.resume(onHeartbeat: () {
            heartbeatCount++;
          });
          expect(heartbeatCount, 2); // immediate on resume

          async.elapse(const Duration(seconds: 30));
          expect(heartbeatCount, 3); // periodic resumes

          manager.dispose();
        });
      });
    });

    // --- Walker presence polling timer ---
    group('Walker presence polling', () {
      test('polls every 15 seconds', () {
        fakeAsync((async) {
          int pollCount = 0;
          final manager = WalkerPresencePoller();
          manager.startPolling(onPoll: () {
            pollCount++;
          });

          // Immediate first poll
          expect(pollCount, 1);

          async.elapse(const Duration(seconds: 15));
          expect(pollCount, 2);

          async.elapse(const Duration(seconds: 15));
          expect(pollCount, 3);

          manager.dispose();
        });
      });

      test('stops polling on dispose', () {
        fakeAsync((async) {
          int pollCount = 0;
          final manager = WalkerPresencePoller();
          manager.startPolling(onPoll: () {
            pollCount++;
          });

          expect(pollCount, 1);
          manager.dispose();

          async.elapse(const Duration(seconds: 30));
          expect(pollCount, 1);
        });
      });
    });
  });
}
