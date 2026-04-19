import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';

/// Full-screen semi-transparent overlay shown while a walk is being started.
///
/// Prevents blank white flash between tapping "Start Walk" and the
/// active walk map screen appearing. Place inside a [Stack] on top of
/// the screen content.
class StartWalkLoadingOverlay extends StatelessWidget {
  const StartWalkLoadingOverlay({super.key, required this.visible});

  /// Whether the overlay is currently shown.
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return AbsorbPointer(
      absorbing: true,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PawProgressIndicator(
                size: 48,
                strokeWidth: 4,
                color: AppColors.goldenPaw,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Starting walk...',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
