import 'package:flutter/material.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';

/// A looping walking-dog animation used on loader screens.
///
/// Authored in Remotion (`animations/walking-dog/` at the repo root) and
/// exported as a GIF. Flutter's [Image.asset] plays animated GIFs natively
/// with built-in looping, so no extra runtime dep is needed.
///
/// Respects [MediaQueryData.disableAnimations] (system-level reduce-motion):
/// when true, swaps to the existing [PawProgressIndicator] so the user still
/// sees a motion-indicating UI without the dog animation.
///
/// Pawgo brand colors are baked into the GIF (warm caramel body, light belly,
/// cacao brown ear). To re-theme, edit `animations/walking-dog/src/Root.tsx`
/// `defaultProps` and re-export via `npm run export-gif`.
class WalkingDogAnimation extends StatelessWidget {
  const WalkingDogAnimation({
    super.key,
    this.size = 200,
    this.semanticsLabel,
  });

  /// Edge length of the rendered animation in logical pixels.
  /// The source GIF is 200×200; rendering larger may look soft.
  final double size;

  /// Optional semantics label, defaults to a generic "Loading" message.
  final String? semanticsLabel;

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
            : Image.asset(
                'lib/assets/animations/walking_dog.gif',
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
      ),
    );
  }
}
