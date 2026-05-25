import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/widgets/range_slider_section.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('RangeSliderSection', () {
    testWidgets('renders title, unit chip, Min/Max value labels, and a RangeSlider',
        (tester) async {
      await tester.pumpWidget(wrap(
        RangeSliderSection(
          title: 'Proximity',
          unit: 'km',
          min: 0,
          max: 20,
          values: const RangeValues(2, 8),
          onChanged: (_) {},
        ),
      ));

      expect(find.text('Proximity'), findsOneWidget);
      // Unit chip should render the unit string visibly.
      expect(find.text('km'), findsWidgets);
      // Min and Max labels each render their integer value with the unit.
      expect(find.text('Min'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
      expect(find.text('2 km'), findsOneWidget);
      expect(find.text('8 km'), findsOneWidget);
      // The RangeSlider itself is present.
      expect(find.byType(RangeSlider), findsOneWidget);
    });

    testWidgets('onChanged fires when the RangeSlider value changes', (tester) async {
      RangeValues? captured;
      await tester.pumpWidget(wrap(
        RangeSliderSection(
          title: 'Price',
          unit: 'MXN',
          min: 50,
          max: 500,
          values: const RangeValues(100, 300),
          onChanged: (v) => captured = v,
        ),
      ));

      // Drive the RangeSlider directly via the widget's onChanged.
      final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
      slider.onChanged!(const RangeValues(120, 280));
      expect(captured, const RangeValues(120, 280));
    });

    testWidgets(
        'optional toggle is rendered when toggleLabel + onToggleChanged are provided',
        (tester) async {
      bool? toggled;
      await tester.pumpWidget(wrap(
        RangeSliderSection(
          title: 'Proximity',
          unit: 'km',
          min: 0,
          max: 20,
          values: const RangeValues(1, 5),
          onChanged: (_) {},
          toggleLabel: 'Only show walkers in this range',
          toggleValue: false,
          onToggleChanged: (v) => toggled = v,
        ),
      ));

      expect(find.text('Only show walkers in this range'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(toggled, isTrue);
    });

    testWidgets('toggle is omitted when no toggleLabel is provided',
        (tester) async {
      await tester.pumpWidget(wrap(
        RangeSliderSection(
          title: 'Price',
          unit: 'MXN',
          min: 50,
          max: 500,
          values: const RangeValues(100, 300),
          onChanged: (_) {},
        ),
      ));

      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('value labels honor the valueLabelFormatter when provided',
        (tester) async {
      await tester.pumpWidget(wrap(
        RangeSliderSection(
          title: 'Price',
          unit: 'MXN',
          min: 50,
          max: 500,
          values: const RangeValues(100, 300),
          onChanged: (_) {},
          valueLabelFormatter: (v) => '\$${v.round()}',
        ),
      ));

      // Custom formatter wins over default "{n} {unit}" rendering.
      expect(find.text('\$100'), findsOneWidget);
      expect(find.text('\$300'), findsOneWidget);
    });
  });
}
