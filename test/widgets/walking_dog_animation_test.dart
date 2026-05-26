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
    testWidgets('renders the GIF asset at the requested size', (tester) async {
      await tester.pumpWidget(_wrap(const WalkingDogAnimation(size: 150)));

      final sizedBox = tester.widget<SizedBox>(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 150 && w.height == 150,
        ),
      );
      expect(sizedBox.width, 150);

      final image = tester.widget<Image>(find.byType(Image));
      final assetImage = image.image as AssetImage;
      expect(assetImage.assetName, 'lib/assets/animations/walking_dog.gif');
      expect(image.fit, BoxFit.contain);
      expect(image.gaplessPlayback, isTrue);
    });

    testWidgets('default size is 200', (tester) async {
      await tester.pumpWidget(_wrap(const WalkingDogAnimation()));
      final sizedBox = tester.widget<SizedBox>(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 200 && w.height == 200,
        ),
      );
      expect(sizedBox.width, 200);
    });

    testWidgets('falls back to PawProgressIndicator under reduce-motion',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const WalkingDogAnimation(),
        disableAnimations: true,
      ));
      expect(find.byType(PawProgressIndicator), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('exposes a Semantics node with the provided label',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const WalkingDogAnimation(semanticsLabel: 'Finding walkers')),
      );
      expect(find.bySemanticsLabel('Finding walkers'), findsOneWidget);
    });

    testWidgets('Semantics label defaults to "Loading"', (tester) async {
      await tester.pumpWidget(_wrap(const WalkingDogAnimation()));
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });
  });
}
