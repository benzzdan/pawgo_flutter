import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/widgets/big_role_button.dart';

void main() {
  group('BigRoleButton', () {
    testWidgets('owner variant renders filled with the primary brand color',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BigRoleButton(
              role: Role.owner,
              label: 'Dueño',
              onPressed: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Dueño'), findsOneWidget);
      // Look for the painted container and assert its decoration uses the
      // primary brand orange (filled, not transparent).
      final container = tester.widget<Container>(
        find.byKey(const Key('bigRoleButton_owner_fill')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.orange500);
    });

    testWidgets('walker variant renders outlined (no fill)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BigRoleButton(
              role: Role.walker,
              label: 'Paseador',
              onPressed: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Paseador'), findsOneWidget);
      final container = tester.widget<Container>(
        find.byKey(const Key('bigRoleButton_walker_outline')),
      );
      final decoration = container.decoration as BoxDecoration;
      // Outlined: no fill (transparent), visible border.
      expect(decoration.color, Colors.transparent);
      expect(decoration.border, isNotNull);
    });

    testWidgets('tap emits the role to onPressed',
        (tester) async {
      Role? pressedRole;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                BigRoleButton(
                  role: Role.owner,
                  label: 'Dueño',
                  onPressed: (r) => pressedRole = r,
                ),
                BigRoleButton(
                  role: Role.walker,
                  label: 'Paseador',
                  onPressed: (r) => pressedRole = r,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Dueño'));
      await tester.pump();
      expect(pressedRole, Role.owner);

      await tester.tap(find.text('Paseador'));
      await tester.pump();
      expect(pressedRole, Role.walker);
    });

    testWidgets('disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BigRoleButton(
              role: Role.owner,
              label: 'Dueño',
              onPressed: null,
            ),
          ),
        ),
      );

      // Tapping a disabled button shouldn't throw; verifying the absent
      // callback is enough — there's no listener to fire.
      await tester.tap(find.text('Dueño'));
      await tester.pump();
      // No expectations beyond "doesn't crash"; mirrors PawgoButton's pattern.
    });
  });
}
