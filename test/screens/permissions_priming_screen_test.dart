import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:pawgo/screens/permissions_priming_screen.dart';
import 'package:pawgo/widgets/permission_card.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('PermissionsPrimingScreen', () {
    // Make the test viewport tall enough to render the two cards + Continue
    // CTA without scrolling so taps don't miss.
    void widenViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
    }

    final pushedRoutes = <(String?, Object?)>[];

    Widget buildHarness({
      required String role,
      required Future<bool> Function() requestLocation,
      required Future<bool> Function() requestNotifications,
    }) {
      pushedRoutes.clear();
      return MaterialApp(
        initialRoute: '/permissions',
        onGenerateRoute: (settings) {
          if (settings.name == '/permissions') {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => PermissionsPrimingScreen(
                role: role,
                requestLocation: requestLocation,
                requestNotifications: requestNotifications,
              ),
            );
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => Scaffold(body: Text('stub-${settings.name}')),
          );
        },
        navigatorObservers: [_SpyObserver(pushedRoutes)],
      );
    }

    testWidgets('renders two PermissionCards (location + notifications)',
        (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildHarness(
        role: 'owner',
        requestLocation: () async => true,
        requestNotifications: () async => true,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(PermissionCard), findsNWidgets(2));
    });

    testWidgets('tapping Allow updates the corresponding card pill',
        (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildHarness(
        role: 'owner',
        requestLocation: () async => true,
        requestNotifications: () async => false,
      ));
      await tester.pumpAndSettle();

      // Both pills start as notYet.
      expect(find.byKey(const Key('permissionCardPill_notYet')),
          findsNWidgets(2));

      // Location card -> tap Allow.
      await tester.tap(find.byKey(const Key('permissionsPriming_allowLocation')));
      await tester.pumpAndSettle();

      // After tapping, location flips to granted (true), notifications stays notYet.
      expect(find.byKey(const Key('permissionCardPill_granted')), findsOneWidget);
      expect(find.byKey(const Key('permissionCardPill_notYet')), findsOneWidget);
    });

    testWidgets('denied result paints the denied pill', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildHarness(
        role: 'owner',
        requestLocation: () async => false,
        requestNotifications: () async => false,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('permissionsPriming_allowLocation')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('permissionCardPill_denied')), findsOneWidget);
    });

    testWidgets('Continue routes owners to /dog-onboarding regardless of grants',
        (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildHarness(
        role: 'owner',
        requestLocation: () async => false,
        requestNotifications: () async => false,
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
          find.byKey(const Key('permissionsPriming_continue')));
      await tester.tap(find.byKey(const Key('permissionsPriming_continue')));
      await tester.pumpAndSettle();

      expect(pushedRoutes.last.$1, '/dog-onboarding');
    });

    testWidgets('Continue routes walkers to /walker-application',
        (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildHarness(
        role: 'walker',
        requestLocation: () async => true,
        requestNotifications: () async => true,
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
          find.byKey(const Key('permissionsPriming_continue')));
      await tester.tap(find.byKey(const Key('permissionsPriming_continue')));
      await tester.pumpAndSettle();

      expect(pushedRoutes.last.$1, '/walker-application');
    });
  });
}

class _SpyObserver extends NavigatorObserver {
  _SpyObserver(this.pushed);
  final List<(String?, Object?)> pushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add((route.settings.name, route.settings.arguments));
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      pushed.add((newRoute.settings.name, newRoute.settings.arguments));
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
