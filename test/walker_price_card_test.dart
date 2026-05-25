import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/widgets/walker_price_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('WalkerPriceCard', () {
    testWidgets('renders the hourly rate prominently with the MXN unit',
        (tester) async {
      await tester.pumpWidget(wrap(
        const WalkerPriceCard(hourlyRateMxn: 180),
      ));

      // Rate appears as "$180" with a small unit label nearby.
      expect(find.text('\$180'), findsOneWidget);
      expect(find.textContaining('MXN'), findsWidgets);
    });

    testWidgets('shows a "From" prefix label by default', (tester) async {
      await tester.pumpWidget(wrap(
        const WalkerPriceCard(hourlyRateMxn: 100),
      ));

      expect(find.text('From'), findsOneWidget);
    });

    testWidgets('shows the per-hour caption', (tester) async {
      await tester.pumpWidget(wrap(
        const WalkerPriceCard(hourlyRateMxn: 250),
      ));

      // "per hour" caption — text is localized client-side; for now we
      // assert the literal English wording the widget ships with.
      expect(find.text('per hour'), findsOneWidget);
    });

    testWidgets('rounds non-integer rates to whole pesos', (tester) async {
      await tester.pumpWidget(wrap(
        const WalkerPriceCard(hourlyRateMxn: 175.50),
      ));

      // Pesos don't carry decimals in this UI — round to whole.
      expect(find.text('\$176'), findsOneWidget);
    });
  });
}
