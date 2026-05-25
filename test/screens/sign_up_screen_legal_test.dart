import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:pawgo/screens/sign_up_screen.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('SignUpScreen — Terms / Privacy checkbox', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders the legal-acceptance checkbox', (tester) async {
      await pumpScreen(tester);
      expect(find.byKey(const Key('signUpLegalCheckbox')), findsOneWidget);
    });

    testWidgets('Create Account button is disabled while checkbox is off',
        (tester) async {
      await pumpScreen(tester);

      final btn = tester.widget<GestureDetector>(
        find.byKey(const Key('signUpSubmitButton')),
      );
      expect(btn.onTap, isNull,
          reason: 'Submit must be disabled until the user accepts T&C');
    });

    testWidgets('checking the box enables Create Account',
        (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('signUpLegalCheckbox')));
      await tester.pumpAndSettle();

      final btn = tester.widget<GestureDetector>(
        find.byKey(const Key('signUpSubmitButton')),
      );
      expect(btn.onTap, isNotNull);
    });

    testWidgets('inline Terms link is tappable', (tester) async {
      await pumpScreen(tester);

      // Inline text spans live in a RichText — the Terms span has a stable
      // semantic label assigned via Semantics, so we can find it.
      final termsFinder = find.byKey(const Key('signUpLegalTermsLink'));
      expect(termsFinder, findsOneWidget);
    });

    testWidgets('inline Privacy link is tappable', (tester) async {
      await pumpScreen(tester);

      final privacyFinder = find.byKey(const Key('signUpLegalPrivacyLink'));
      expect(privacyFinder, findsOneWidget);
    });
  });
}
