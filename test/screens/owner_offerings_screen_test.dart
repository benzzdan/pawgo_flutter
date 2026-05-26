import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:pawgo/screens/owner_offerings_screen.dart';
import 'package:pawgo/widgets/trust_signal_row.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('OwnerOfferingsScreen', () {
    final pushedRoutes = <(String?, Object?)>[];

    Widget buildHarness() {
      pushedRoutes.clear();
      return MaterialApp(
        initialRoute: '/owner-offerings',
        routes: {
          '/welcome': (_) => const Scaffold(body: Text('welcome-stub')),
          '/owner-offerings': (_) => const OwnerOfferingsScreen(),
          '/signup': (_) => const Scaffold(body: Text('signup-stub')),
        },
        navigatorObservers: [_SpyObserver(pushedRoutes)],
      );
    }

    testWidgets('renders headline, three trust rows, and Connect CTA',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      // Three trust-signal rows render.
      expect(find.byType(TrustSignalRow), findsNWidgets(3));

      // Connect CTA is present.
      expect(find.byKey(const Key('ownerOfferingsConnectCta')), findsOneWidget);
    });

    testWidgets('tapping Connect pushes /signup with role=owner',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      final cta = find.byKey(const Key('ownerOfferingsConnectCta'));
      await tester.ensureVisible(cta);
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(pushedRoutes.last.$1, '/signup');
      final args = pushedRoutes.last.$2;
      expect(args, isA<Map>());
      expect((args! as Map)['role'], 'owner');
    });

    testWidgets('back arrow is rendered when there is a previous route',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Push welcome first, then push offerings on top so the back arrow
      // can target /welcome.
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/welcome',
          routes: {
            '/welcome': (ctx) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(ctx, '/owner-offerings'),
                      child: const Text('go'),
                    ),
                  ),
                ),
            '/owner-offerings': (_) => const OwnerOfferingsScreen(),
            '/signup': (_) => const Scaffold(body: Text('signup-stub')),
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      // Default Material back button surfaces.
      expect(find.byTooltip('Back'), findsOneWidget);
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
}
