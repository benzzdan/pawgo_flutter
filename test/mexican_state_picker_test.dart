import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/constants/mexican_states.dart';
import 'package:pawgo/widgets/mexican_state_picker_field.dart';

void main() {
  group('Mexican states constant', () {
    test('contains exactly 32 entries', () {
      expect(mexicanStates.length, 32);
    });

    test('is in the exact PRD-specified alphabetical order', () {
      // First and last entries verify the order bookends
      expect(mexicanStates.first, 'Aguascalientes');
      expect(mexicanStates.last, 'Zacatecas');
      // Ciudad de México comes before Coahuila (index 6, 7)
      expect(mexicanStates.indexOf('Ciudad de México'), 6);
      expect(mexicanStates.indexOf('Coahuila'), 7);
      // México comes before Michoacán
      expect(mexicanStates.indexOf('México'),
          lessThan(mexicanStates.indexOf('Michoacán')));
    });

    test('contains Ciudad de México', () {
      expect(mexicanStates, contains('Ciudad de México'));
    });

    test('contains all expected states', () {
      const expected = [
        'Aguascalientes',
        'Baja California',
        'Baja California Sur',
        'Campeche',
        'Chiapas',
        'Chihuahua',
        'Ciudad de México',
        'Coahuila',
        'Colima',
        'Durango',
        'Guanajuato',
        'Guerrero',
        'Hidalgo',
        'Jalisco',
        'México',
        'Michoacán',
        'Morelos',
        'Nayarit',
        'Nuevo León',
        'Oaxaca',
        'Puebla',
        'Querétaro',
        'Quintana Roo',
        'San Luis Potosí',
        'Sinaloa',
        'Sonora',
        'Tabasco',
        'Tamaulipas',
        'Tlaxcala',
        'Veracruz',
        'Yucatán',
        'Zacatecas',
      ];
      for (final state in expected) {
        expect(mexicanStates, contains(state));
      }
    });
  });

  group('MexicanStatePickerField widget', () {
    testWidgets('displays hint when no value selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MexicanStatePickerField(
              selectedState: null,
              onStateSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('State'), findsOneWidget);
    });

    testWidgets('displays selected state value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MexicanStatePickerField(
              selectedState: 'Jalisco',
              onStateSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Jalisco'), findsOneWidget);
    });

    testWidgets('does NOT contain a TextField (no keyboard input)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MexicanStatePickerField(
              selectedState: null,
              onStateSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('tapping opens a bottom sheet showing states',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MexicanStatePickerField(
              selectedState: null,
              onStateSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(MexicanStatePickerField));
      await tester.pumpAndSettle();

      // Verify header appears
      expect(find.text('Select State'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // First few states visible near the top of the list
      expect(find.text('Aguascalientes'), findsOneWidget);
      expect(find.text('Baja California'), findsOneWidget);
      expect(find.text('Campeche'), findsOneWidget);
    });

    testWidgets('selecting a state calls onStateSelected and closes sheet',
        (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MexicanStatePickerField(
              selectedState: null,
              onStateSelected: (s) => selected = s,
            ),
          ),
        ),
      );

      // Open the picker
      await tester.tap(find.byType(MexicanStatePickerField));
      await tester.pumpAndSettle();

      // Select "Campeche" (visible near top of list)
      await tester.tap(find.text('Campeche'));
      await tester.pumpAndSettle();

      expect(selected, 'Campeche');

      // Bottom sheet should be dismissed
      expect(find.text('Aguascalientes'), findsNothing);
    });

    testWidgets('cancel closes the picker without changing selection',
        (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MexicanStatePickerField(
              selectedState: 'Jalisco',
              onStateSelected: (s) => selected = s,
            ),
          ),
        ),
      );

      // Open the picker
      await tester.tap(find.byType(MexicanStatePickerField));
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Callback should NOT have been called
      expect(selected, isNull);

      // Bottom sheet dismissed
      expect(find.text('Aguascalientes'), findsNothing);
    });

    testWidgets('pre-selected state shows checkmark in picker',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MexicanStatePickerField(
              selectedState: 'Chiapas',
              onStateSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(MexicanStatePickerField));
      await tester.pumpAndSettle();

      // Find the checkmark icon — should appear exactly once (for Chiapas)
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });
}
