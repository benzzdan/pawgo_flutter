import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:pawgo/screens/welcome_screen.dart';
import 'package:pawgo/widgets/big_role_button.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('WelcomeScreen', () {
    /// A spy NavigatorObserver that records every push it sees so tests can
    /// inspect (route name, arguments) without needing a real Navigator stack.
    /// We capture into a top-level list so the helper is reusable.
    final pushedRoutes = <(String?, Object?)>[];

    Widget buildHarness() {
      pushedRoutes.clear();
      return MaterialApp(
        initialRoute: '/welcome',
        routes: {
          '/welcome': (_) => const WelcomeScreen(),
          // Stub destinations so pushNamed doesn't blow up.
          '/signup': (_) => const Scaffold(body: Text('signup-stub')),
          '/login': (_) => const Scaffold(body: Text('login-stub')),
        },
        navigatorObservers: [_SpyObserver(pushedRoutes)],
      );
    }

    testWidgets('renders tagline, two role buttons, and Log In link',
        (tester) async {
      await tester.pumpWidget(buildHarness());

      // Tagline appears somewhere on screen.
      expect(find.byKey(const Key('welcomeTagline')), findsOneWidget);

      // Two role buttons render (owner + walker).
      expect(find.byType(BigRoleButton), findsNWidgets(2));

      // The "Log In" link is present and tappable.
      expect(find.byKey(const Key('welcomeLoginLink')), findsOneWidget);
    });

    testWidgets('tapping the owner button pushes /signup with role=owner',
        (tester) async {
      await tester.pumpWidget(buildHarness());

      final ownerButton = find.byKey(const Key('welcomeOwnerButton'));
      expect(ownerButton, findsOneWidget);

      await tester.tap(ownerButton);
      await tester.pumpAndSettle();

      expect(pushedRoutes.last.$1, '/signup');
      final args = pushedRoutes.last.$2;
      expect(args, isA<Map>());
      expect((args! as Map)['role'], 'owner');
    });

    testWidgets('tapping the walker button pushes /signup with role=walker',
        (tester) async {
      await tester.pumpWidget(buildHarness());

      final walkerButton = find.byKey(const Key('welcomeWalkerButton'));
      expect(walkerButton, findsOneWidget);

      await tester.tap(walkerButton);
      await tester.pumpAndSettle();

      expect(pushedRoutes.last.$1, '/signup');
      final args = pushedRoutes.last.$2;
      expect(args, isA<Map>());
      expect((args! as Map)['role'], 'walker');
    });

    testWidgets('tapping the Log In link pushes /login', (tester) async {
      // Larger surface so the bottom-most TextButton renders in the viewport
      // without scrolling; default test surface clips it off-screen.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('welcomeLoginLink')));
      await tester.tap(find.byKey(const Key('welcomeLoginLink')));
      await tester.pumpAndSettle();

      expect(pushedRoutes.last.$1, '/login');
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
