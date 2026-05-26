import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:pawgo/screens/dog_onboarding_intro_screen.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('DogOnboardingIntroScreen', () {
    final pushedRoutes = <(String?, Object?)>[];
    final replacedRoutes = <(String?, Object?)>[];

    Widget buildHarness({
      Future<void> Function()? onComplete,
    }) {
      pushedRoutes.clear();
      replacedRoutes.clear();
      return MaterialApp(
        home: DogOnboardingIntroScreen(
          onMarkComplete: onComplete ?? () async {},
        ),
        navigatorObservers: [_SpyObserver(pushedRoutes, replacedRoutes)],
        // Stub destinations so navigation doesn't crash.
        routes: {
          // PR C: the dog form stub immediately pops with `true` so the
          // intro's _onAddMyDog can await the result and continue on to
          // /finding-walkers.
          '/dog-profile-form': (ctx) {
            // Schedule the pop after the route is built.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pop(ctx, true);
            });
            return const Scaffold(body: Text('stub-dog-profile'));
          },
          '/home': (_) => const Scaffold(body: Text('stub-home')),
          '/finding-walkers': (_) =>
              const Scaffold(body: Text('stub-finding-walkers')),
        },
      );
    }

    testWidgets('renders both CTAs', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dogOnboardingAddCta')), findsOneWidget);
      expect(find.byKey(const Key('dogOnboardingSkipCta')), findsOneWidget);
    });

    testWidgets(
        'Add my dog pushes /dog-profile-form then forwards to /finding-walkers',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('dogOnboardingAddCta')));
      await tester.tap(find.byKey(const Key('dogOnboardingAddCta')));
      await tester.pumpAndSettle();

      // PR C: Add my dog pushes (not replaces) the form, so /dog-profile-form
      // arrives via didPush; the form stub auto-pops with `true`, and the
      // intro then pushReplacement to /finding-walkers.
      expect(
        pushedRoutes.any((entry) => entry.$1 == '/dog-profile-form'),
        isTrue,
        reason: 'Add my dog should push /dog-profile-form',
      );
      expect(
        replacedRoutes.any((entry) => entry.$1 == '/finding-walkers'),
        isTrue,
        reason:
            'After the form pops with success, intro should replace to /finding-walkers',
      );
    });

    testWidgets(
        'Skip for now calls onMarkComplete and routes to /finding-walkers',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int completeCalls = 0;
      await tester.pumpWidget(buildHarness(
        onComplete: () async => completeCalls++,
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('dogOnboardingSkipCta')));
      await tester.tap(find.byKey(const Key('dogOnboardingSkipCta')));
      await tester.pumpAndSettle();

      expect(completeCalls, 1,
          reason: 'Skip should mark onboarding complete on the server');
      // PR C: Skip now goes through /finding-walkers loader on the way home,
      // not straight to /home.
      expect(
        replacedRoutes.any((entry) => entry.$1 == '/finding-walkers'),
        isTrue,
        reason: 'Skip should replace to /finding-walkers',
      );
    });
  });
}

class _SpyObserver extends NavigatorObserver {
  _SpyObserver(this.pushed, this.replaced);
  final List<(String?, Object?)> pushed;
  final List<(String?, Object?)> replaced;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add((route.settings.name, route.settings.arguments));
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      replaced.add((newRoute.settings.name, newRoute.settings.arguments));
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
