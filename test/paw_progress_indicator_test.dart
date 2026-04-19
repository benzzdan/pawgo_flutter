import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';

void main() {
  group('PawProgressIndicator', () {
    testWidgets('renders with branded styling', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: PawProgressIndicator()),
          ),
        ),
      );

      // Should find the custom widget
      expect(find.byType(PawProgressIndicator), findsOneWidget);

      // Should contain a CircularProgressIndicator underneath
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Verify the indicator uses round stroke cap and brand color
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.strokeCap, StrokeCap.round);
      expect(indicator.color, const Color(0xFFF4A832)); // AppColors.goldenPaw
    });

    testWidgets('respects custom size parameter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: PawProgressIndicator(size: 48)),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.width, 48);
      expect(sizedBox.height, 48);
    });

    testWidgets('supports custom color override', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PawProgressIndicator(color: Colors.white),
            ),
          ),
        ),
      );

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, Colors.white);
    });

    testWidgets('supports custom strokeWidth', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PawProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.strokeWidth, 2);
    });
  });
}
