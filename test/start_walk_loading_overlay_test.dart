import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/widgets/start_walk_loading_overlay.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';

void main() {
  group('StartWalkLoadingOverlay', () {
    testWidgets('shows overlay with PawProgressIndicator when visible is true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StartWalkLoadingOverlay(visible: true),
          ),
        ),
      );

      // Overlay should be visible
      expect(find.byType(StartWalkLoadingOverlay), findsOneWidget);
      // Should contain a PawProgressIndicator
      expect(find.byType(PawProgressIndicator), findsOneWidget);
      // Should show "Starting walk..." text
      expect(find.text('Starting walk...'), findsOneWidget);
    });

    testWidgets('hides content when visible is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StartWalkLoadingOverlay(visible: false),
          ),
        ),
      );

      // Overlay widget exists but should not show the indicator
      expect(find.byType(PawProgressIndicator), findsNothing);
      expect(find.text('Starting walk...'), findsNothing);
    });

    testWidgets('overlay absorbs pointer events when visible',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StartWalkLoadingOverlay(visible: true),
          ),
        ),
      );

      // The overlay's AbsorbPointer should be absorbing
      final absorbPointer = tester.widget<AbsorbPointer>(
        find.descendant(
          of: find.byType(StartWalkLoadingOverlay),
          matching: find.byType(AbsorbPointer),
        ),
      );
      expect(absorbPointer.absorbing, isTrue);
    });
  });
}
