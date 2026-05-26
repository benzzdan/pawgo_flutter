import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/widgets/walking_dog_animation.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('WalkingDogAnimation', () {
    testWidgets('default size in reduce-motion fallback is 240', (tester) async {
      // Rive can't load assets in the test runtime; use the reduce-motion path
      // to inspect the outer SizedBox without instantiating Rive.
      await tester.pumpWidget(_wrap(
        const WalkingDogAnimation(),
        disableAnimations: true,
      ));
      final sizedBox = tester.widget<SizedBox>(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 240 && w.height == 240,
        ),
      );
      expect(sizedBox.width, 240);
    });

    testWidgets('requested size passes through (reduce-motion fallback)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const WalkingDogAnimation(size: 150),
        disableAnimations: true,
      ));
      final sizedBox = tester.widget<SizedBox>(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 150 && w.height == 150,
        ),
      );
      expect(sizedBox.width, 150);
    });

    testWidgets('falls back to PawProgressIndicator under reduce-motion',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const WalkingDogAnimation(),
        disableAnimations: true,
      ));
      expect(find.byType(PawProgressIndicator), findsOneWidget);
    });

    testWidgets('exposes a Semantics node with the provided label',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const WalkingDogAnimation(semanticsLabel: 'Finding walkers'),
        disableAnimations: true,
      ));
      expect(find.bySemanticsLabel('Finding walkers'), findsOneWidget);
    });

    testWidgets('Semantics label defaults to "Loading"', (tester) async {
      await tester.pumpWidget(_wrap(
        const WalkingDogAnimation(),
        disableAnimations: true,
      ));
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });
  });
}
