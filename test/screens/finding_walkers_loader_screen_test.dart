import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:pawgo/screens/finding_walkers_loader_screen.dart';
import 'package:pawgo/widgets/walking_dog_animation.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('FindingWalkersLoaderScreen', () {
    final replacedRoutes = <(String?, Object?)>[];

    Widget buildHarness({
      required Future<void> Function() fetchWalkers,
      Duration minDisplay = const Duration(milliseconds: 200),
    }) {
      replacedRoutes.clear();
      return MaterialApp(
        home: FindingWalkersLoaderScreen(
          fetchWalkers: fetchWalkers,
          minDisplay: minDisplay,
        ),
        routes: {
          '/home': (_) => const Scaffold(body: Text('home-stub')),
        },
        navigatorObservers: [_SpyObserver(replacedRoutes)],
      );
    }

    testWidgets('renders WalkingDogAnimation and bilingual headline',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final completer = Completer<void>();
      addTearDown(() {
        if (!completer.isCompleted) completer.complete();
      });

      await tester.pumpWidget(
        MediaQuery(
          // Reduce motion so Rive doesn't load and we can finish pumping.
          data: const MediaQueryData(disableAnimations: true),
          child: buildHarness(
            // Pending future so the loader stays in its loading state for
            // the duration of the assertions. We complete it on teardown.
            fetchWalkers: () => completer.future,
            minDisplay: const Duration(milliseconds: 50),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(WalkingDogAnimation), findsOneWidget);
      // ES + EN are concatenated inline in one Text node.
      expect(
        find.textContaining('Encontrando paseadores cerca de ti'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Finding walkers near you'),
        findsOneWidget,
      );

      // Drain the pending future + minDisplay timer + post-frame navigation
      // so the test framework doesn't complain about leaked timers.
      completer.complete();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
    });

    testWidgets('navigates to /home once fetch resolves AND minDisplay elapses',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Fetch resolves immediately, but minDisplay is 200ms — so the
      // transition should be deferred until the 200ms have elapsed.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: buildHarness(
            fetchWalkers: () async {},
            minDisplay: const Duration(milliseconds: 200),
          ),
        ),
      );
      // Immediately after first frame, fetch completes but minDisplay
      // hasn't elapsed yet — we should still be on the loader.
      await tester.pump();
      expect(
        replacedRoutes.any((r) => r.$1 == '/home'),
        isFalse,
        reason: 'minDisplay should hold the loader visible briefly',
      );

      // Wait past minDisplay.
      await tester.pump(const Duration(milliseconds: 250));
      // Flush microtasks so the post-frame replace runs.
      await tester.pump();

      expect(
        replacedRoutes.any((r) => r.$1 == '/home'),
        isTrue,
        reason: 'After fetch + minDisplay, loader should pushReplacement /home',
      );
    });

    testWidgets('waits for slow fetch even when minDisplay elapses first',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final completer = Completer<void>();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: buildHarness(
            // minDisplay is short, but fetch hasn't resolved — should wait.
            minDisplay: const Duration(milliseconds: 50),
            fetchWalkers: () => completer.future,
          ),
        ),
      );

      // Past minDisplay, but fetch still pending.
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        replacedRoutes.any((r) => r.$1 == '/home'),
        isFalse,
        reason: 'Should NOT navigate until fetch resolves',
      );

      // Resolve fetch.
      completer.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(
        replacedRoutes.any((r) => r.$1 == '/home'),
        isTrue,
        reason: 'After fetch resolves, navigation should fire',
      );
    });

    testWidgets('surfaces error and Continue button on fetch failure',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: buildHarness(
            fetchWalkers: () async => throw Exception('Network down'),
            minDisplay: const Duration(milliseconds: 50),
          ),
        ),
      );

      // Wait for the future to reject + frame to rebuild.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Did NOT auto-navigate.
      expect(
        replacedRoutes.any((r) => r.$1 == '/home'),
        isFalse,
        reason: 'On error we should not auto-route',
      );

      // Continue button is rendered.
      final continueBtn =
          find.byKey(const Key('findingWalkersContinueCta'));
      expect(continueBtn, findsOneWidget);

      // Tapping it routes to /home.
      await tester.tap(continueBtn);
      await tester.pump();

      expect(
        replacedRoutes.any((r) => r.$1 == '/home'),
        isTrue,
        reason: 'Continue button should manually advance to /home',
      );
    });
  });
}

class _SpyObserver extends NavigatorObserver {
  _SpyObserver(this.replaced);
  final List<(String?, Object?)> replaced;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      replaced.add((newRoute.settings.name, newRoute.settings.arguments));
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
