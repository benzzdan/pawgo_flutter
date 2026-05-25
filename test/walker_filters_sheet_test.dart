import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/screens/find_screen.dart' show AdvancedFilters;
import 'package:pawgo/widgets/range_slider_section.dart';
import 'package:pawgo/widgets/walker_filters_sheet.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('WalkerFiltersSheet', () {
    testWidgets('renders Proximity range, Price range, and the existing controls',
        (tester) async {
      await tester.pumpWidget(wrap(
        WalkerFiltersSheet(
          initial: const AdvancedFilters(),
          onApply: (_) {},
          onReset: () {},
        ),
      ));

      // Two RangeSliderSections: Proximity + Price.
      expect(find.byType(RangeSliderSection), findsNWidgets(2));
      // Existing controls preserved.
      expect(find.text('Minimum Experience'), findsOneWidget);
      expect(find.text('Background Checked'), findsOneWidget);
      // Apply + Reset buttons.
      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('pre-populates from the initial AdvancedFilters', (tester) async {
      await tester.pumpWidget(wrap(
        WalkerFiltersSheet(
          initial: const AdvancedFilters(
            minDistanceKm: 2,
            maxDistanceKm: 7,
            minRate: 120,
            maxRate: 280,
            minExperience: 3,
            backgroundChecked: true,
          ),
          onApply: (_) {},
          onReset: () {},
        ),
      ));

      // Distance: 2 km min, 7 km max.
      expect(find.text('2 km'), findsOneWidget);
      expect(find.text('7 km'), findsOneWidget);
      // Price: \$120 min, \$280 max (custom formatter).
      expect(find.text('\$120'), findsOneWidget);
      expect(find.text('\$280'), findsOneWidget);
    });

    testWidgets('Apply returns the configured AdvancedFilters via the callback',
        (tester) async {
      AdvancedFilters? captured;
      await tester.pumpWidget(wrap(
        WalkerFiltersSheet(
          initial: const AdvancedFilters(
            minDistanceKm: 1,
            maxDistanceKm: 5,
            minRate: 100,
            maxRate: 200,
            minExperience: 2,
            backgroundChecked: true,
            onlyShowInRange: true,
          ),
          onApply: (f) => captured = f,
          onReset: () {},
        ),
      ));

      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!.minDistanceKm, 1);
      expect(captured!.maxDistanceKm, 5);
      expect(captured!.minRate, 100);
      expect(captured!.maxRate, 200);
      expect(captured!.minExperience, 2);
      expect(captured!.backgroundChecked, isTrue);
      expect(captured!.onlyShowInRange, isTrue);
    });

    testWidgets('Apply omits range bounds when sliders sit at the extremes',
        (tester) async {
      // If the user never touched the proximity slider (still at 0..50), we
      // should NOT pass min/maxDistanceKm — that lets the RPC fall back to
      // "no distance filter". Same for price at its full bounds (50..500).
      AdvancedFilters? captured;
      await tester.pumpWidget(wrap(
        WalkerFiltersSheet(
          initial: const AdvancedFilters(),
          onApply: (f) => captured = f,
          onReset: () {},
        ),
      ));

      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!.minDistanceKm, isNull);
      expect(captured!.maxDistanceKm, isNull);
      expect(captured!.minRate, isNull);
      expect(captured!.maxRate, isNull);
      expect(captured!.minExperience, isNull);
      expect(captured!.backgroundChecked, isNull);
    });

    testWidgets('Reset invokes the onReset callback', (tester) async {
      var resetCalls = 0;
      await tester.pumpWidget(wrap(
        WalkerFiltersSheet(
          initial: const AdvancedFilters(maxDistanceKm: 10),
          onApply: (_) {},
          onReset: () => resetCalls++,
        ),
      ));

      await tester.tap(find.text('Reset'));
      await tester.pump();

      expect(resetCalls, 1);
    });

    testWidgets(
        'onlyShowInRange toggle is wired to the proximity slider section',
        (tester) async {
      AdvancedFilters? captured;
      await tester.pumpWidget(wrap(
        WalkerFiltersSheet(
          initial: const AdvancedFilters(
            minDistanceKm: 1,
            maxDistanceKm: 5,
          ),
          onApply: (f) => captured = f,
          onReset: () {},
        ),
      ));

      // Two switches exist: the proximity-section toggle (onlyShowInRange)
      // and the background-checked row. The proximity toggle is the one
      // adjacent to its localized label.
      final toggleSwitch = find.descendant(
        of: find.byType(RangeSliderSection),
        matching: find.byType(Switch),
      );
      expect(toggleSwitch, findsOneWidget);
      await tester.tap(toggleSwitch);
      await tester.pump();

      await tester.tap(find.text('Apply'));
      await tester.pump();
      expect(captured!.onlyShowInRange, isTrue);
    });
  });
}
