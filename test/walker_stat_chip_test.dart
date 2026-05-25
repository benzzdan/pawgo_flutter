import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pawgo/widgets/walker_stat_chip.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('WalkerStatChip', () {
    testWidgets('renders the icon, value, and label it is handed', (tester) async {
      await tester.pumpWidget(wrap(
        WalkerStatChip(
          icon: PhosphorIcons.star(PhosphorIconsStyle.fill),
          value: '4.8',
          label: 'Rating',
        ),
      ));

      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('Rating'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('value and label render in the same chip', (tester) async {
      await tester.pumpWidget(wrap(
        WalkerStatChip(
          icon: PhosphorIcons.briefcase(),
          value: '5 yrs',
          label: 'Experience',
        ),
      ));

      // Find the WalkerStatChip widget itself and check the value+label
      // are both inside it (no accidental layout split).
      final chipFinder = find.byType(WalkerStatChip);
      expect(chipFinder, findsOneWidget);
      expect(
        find.descendant(of: chipFinder, matching: find.text('5 yrs')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: chipFinder, matching: find.text('Experience')),
        findsOneWidget,
      );
    });
  });
}
