import 'package:flutter/material.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';
import 'package:rive/rive.dart';

/// A looping Rive walking-dog animation used on loader screens.
///
/// The Rive source lives at `lib/assets/animations/dog_loader.riv`
/// (community asset — "Dog follows his ball"). Rive renders vectors at
/// native 60fps with autoplay, so this widget is intentionally tiny.
///
/// Respects [MediaQueryData.disableAnimations] (system-level reduce-motion):
/// when true, swaps to the existing [PawProgressIndicator] so the user still
/// sees a motion-indicating UI without the dog animation.
///
/// To replace the underlying animation, swap the .riv file at the same path;
/// no Dart changes needed.
class WalkingDogAnimation extends StatelessWidget {
  const WalkingDogAnimation({
    super.key,
    this.size = 240,
    this.semanticsLabel,
    this.fit = BoxFit.contain,
  });

  /// Edge length of the rendered animation in logical pixels.
  /// Rive scales without quality loss; default 240 reads well on the
  /// finding-walkers loader screen.
  final double size;

  /// Optional semantics label, defaults to a generic "Loading" message.
  final String? semanticsLabel;

  /// How the Rive artboard fits inside the available space.
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return Semantics(
      label: semanticsLabel ?? 'Loading',
      container: true,
      child: SizedBox.square(
        dimension: size,
        child: disableAnimations
            ? const Center(child: PawProgressIndicator())
            : RiveAnimation.asset(
                'lib/assets/animations/dog_loader.riv',
                fit: fit,
                antialiasing: true,
              ),
      ),
    );
  }
}
