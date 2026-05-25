import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:pawgo/config/legal.dart';
import 'package:pawgo/config/legal_placeholder.dart';
import 'package:pawgo/screens/legal_acceptance_screen.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('LegalAcceptanceScreen', () {
    Widget buildHarness(LegalDoc doc, Locale locale) {
      return MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: LegalAcceptanceScreen(doc: doc),
      );
    }

    testWidgets('renders Terms placeholder sections in ES locale',
        (tester) async {
      await tester.pumpWidget(buildHarness(LegalDoc.terms, const Locale('es')));
      await tester.pumpAndSettle();

      // First ES section title should be on screen.
      final esFirst = legalSections(LegalDoc.terms, 'es').first.title;
      expect(find.text(esFirst), findsOneWidget);
    });

    testWidgets('renders Terms placeholder sections in EN locale',
        (tester) async {
      await tester.pumpWidget(buildHarness(LegalDoc.terms, const Locale('en')));
      await tester.pumpAndSettle();

      final enFirst = legalSections(LegalDoc.terms, 'en').first.title;
      expect(find.text(enFirst), findsOneWidget);
    });

    testWidgets('renders Privacy placeholder sections', (tester) async {
      await tester
          .pumpWidget(buildHarness(LegalDoc.privacy, const Locale('es')));
      await tester.pumpAndSettle();

      final first = legalSections(LegalDoc.privacy, 'es').first.title;
      expect(find.text(first), findsOneWidget);
    });

    testWidgets('shows the current document version header', (tester) async {
      await tester.pumpWidget(buildHarness(LegalDoc.terms, const Locale('es')));
      await tester.pumpAndSettle();

      expect(find.textContaining(kTermsVersion), findsOneWidget);
    });

    testWidgets('back button pops the route', (tester) async {
      // Bigger viewport so the AppBar back-button is hit-testable.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool popped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onDidRemovePage: (page) {
              popped = true;
            },
            pages: const [
              MaterialPage(child: Scaffold(body: Text('home'))),
              MaterialPage(
                child: LegalAcceptanceScreen(doc: LegalDoc.terms),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // BackButton lives in the AppBar.
      final backFinder = find.byTooltip('Back');
      expect(backFinder, findsOneWidget);
      await tester.tap(backFinder);
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });
  });
}
