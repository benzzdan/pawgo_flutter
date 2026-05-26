import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/widgets/trust_signal_row.dart';

void main() {
  group('TrustSignalRow', () {
    testWidgets('renders both bilingual labels and an icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrustSignalRow(
              icon: PhosphorIcons.check(),
              labelEs: 'aprobado por veterinario',
              labelEn: 'vet approved',
            ),
          ),
        ),
      );

      // Both labels surface independently so the row is readable in both
      // languages without locale switching.
      expect(find.text('aprobado por veterinario'), findsOneWidget);
      expect(find.text('vet approved'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('icon uses the brand caramel color by default',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrustSignalRow(
              icon: PhosphorIcons.check(),
              labelEs: 'a',
              labelEn: 'b',
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, AppColors.warmCaramel);
    });

    testWidgets('icon color can be overridden', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrustSignalRow(
              icon: PhosphorIcons.check(),
              labelEs: 'a',
              labelEn: 'b',
              iconColor: AppColors.goldenPaw,
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, AppColors.goldenPaw);
    });
  });
}
