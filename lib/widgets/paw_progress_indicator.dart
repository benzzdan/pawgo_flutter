import 'package:flutter/material.dart';
import 'package:pawgo/theme/app_theme.dart';

/// Branded progress indicator with rounded stroke cap and Pawgo golden color.
///
/// Drop-in replacement for [CircularProgressIndicator] across the app.
/// Defaults to 28px size and [AppColors.goldenPaw] color.
class PawProgressIndicator extends StatelessWidget {
  const PawProgressIndicator({
    super.key,
    this.size = 28,
    this.color,
    this.strokeWidth = 3.0,
  });

  /// Diameter of the indicator. Defaults to 28.
  final double size;

  /// Override color. Defaults to [AppColors.goldenPaw].
  final Color? color;

  /// Stroke width. Defaults to 3.0.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        strokeCap: StrokeCap.round,
        color: color ?? AppColors.goldenPaw,
      ),
    );
  }
}
