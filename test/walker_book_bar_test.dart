import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/widgets/walker_book_bar.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(bottomNavigationBar: child));

  group('WalkerBookBar', () {
    testWidgets('renders the CTA label and the hourly rate', (tester) async {
      await tester.pumpWidget(wrap(
        WalkerBookBar(
          hourlyRateMxn: 180,
          onBook: () {},
        ),
      ));

      expect(find.text('Book a walk'), findsOneWidget);
      // Rate appears next to the CTA as "$180 MXN/hr" or similar.
      expect(find.textContaining('180'), findsWidgets);
      expect(find.textContaining('MXN'), findsWidgets);
    });

    testWidgets('onBook fires when the button is tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(
        WalkerBookBar(
          hourlyRateMxn: 100,
          onBook: () => taps++,
        ),
      ));

      await tester.tap(find.text('Book a walk'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('renders disabled state when onBook is null', (tester) async {
      await tester.pumpWidget(wrap(
        const WalkerBookBar(
          hourlyRateMxn: 100,
          onBook: null,
        ),
      ));

      // The button still renders (so the label is findable) but its
      // onPressed callback is null, so taps are absorbed.
      expect(find.text('Book a walk'), findsOneWidget);

      // Look up the first ButtonStyleButton in the tree (ElevatedButton.icon
      // expands into an internal subclass — there may be more than one).
      final buttonFinder = find.byWidgetPredicate((w) =>
          w is ButtonStyleButton, description: 'ButtonStyleButton');
      expect(buttonFinder, findsWidgets);
      final btn = tester.widgetList<ButtonStyleButton>(buttonFinder).first;
      expect(btn.onPressed, isNull);

      // Tap should not throw even with no handler.
      await tester.tap(find.text('Book a walk'));
      await tester.pump();
    });
  });
}
