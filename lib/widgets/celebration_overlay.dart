import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand colors for celebration animations.
class _CelebrationColors {
  static const cacaoBrown = Color(0xFF4A2C2A);
  static const warmCaramel = Color(0xFFC07D4D);
  static const goldenPaw = Color(0xFFF4A832);
  static const softCream = Color(0xFFFFF5E6);
}

/// A reusable full-screen celebration overlay with confetti, animated text,
/// and an illustration. Auto-dismisses after [duration] or on tap.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({
    super.key,
    required this.title,
    required this.subtitle,
    this.illustrationAsset,
    this.confettiColors,
    this.duration = const Duration(seconds: 4),
    this.onDismiss,
  });

  /// Main celebration title text.
  final String title;

  /// Subtitle text shown below the title.
  final String subtitle;

  /// Path to an SVG illustration asset. If null, no illustration is shown.
  final String? illustrationAsset;

  /// Colors for confetti particles. Defaults to brand palette.
  final List<Color>? confettiColors;

  /// Total duration before auto-dismiss. Defaults to 4 seconds.
  final Duration duration;

  /// Called when the overlay is dismissed (tap or auto).
  final VoidCallback? onDismiss;

  /// Shows the CelebrationOverlay as a full-screen overlay entry.
  /// Returns a function to manually dismiss if needed.
  static VoidCallback show(
    BuildContext context, {
    required String title,
    required String subtitle,
    String? illustrationAsset,
    List<Color>? confettiColors,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onDismiss,
  }) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => CelebrationOverlay(
        title: title,
        subtitle: subtitle,
        illustrationAsset: illustrationAsset,
        confettiColors: confettiColors,
        duration: duration,
        onDismiss: () {
          entry.remove();
          onDismiss?.call();
        },
      ),
    );
    Overlay.of(context).insert(entry);
    return () {
      if (entry.mounted) entry.remove();
    };
  }

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late final ConfettiController _confettiController;
  late final AnimationController _dismissController;
  bool _isDismissing = false;

  List<Color> get _confettiColors =>
      widget.confettiColors ??
      [
        _CelebrationColors.goldenPaw,
        _CelebrationColors.warmCaramel,
        _CelebrationColors.softCream,
      ];

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 2500),
    );

    _dismissController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Fire confetti and haptic feedback.
    _confettiController.play();
    HapticFeedback.mediumImpact();

    // Auto-dismiss after the specified duration.
    Future.delayed(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _dismissController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    await _dismissController.forward();
    if (mounted) {
      widget.onDismiss?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Respect reduce-motion accessibility setting.
    final reduceMotion =
        MediaQuery.of(context).accessibleNavigation;

    return FadeTransition(
      opacity: Tween<double>(begin: 1.0, end: 0.0)
          .animate(_dismissController),
      child: GestureDetector(
        onTap: _dismiss,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: _CelebrationColors.cacaoBrown.withValues(alpha: 0.6),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Confetti burst from top-center.
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    maxBlastForce: 20,
                    minBlastForce: 8,
                    numberOfParticles: 35,
                    gravity: 0.2,
                    colors: _confettiColors,
                    createParticlePath: _drawStar,
                  ),
                ),

                // Main content column.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Illustration.
                    if (widget.illustrationAsset != null)
                      _buildIllustration(reduceMotion),

                    const SizedBox(height: 24),

                    // Title.
                    _buildTitle(reduceMotion),

                    const SizedBox(height: 12),

                    // Subtitle.
                    _buildSubtitle(reduceMotion),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration(bool reduceMotion) {
    final illustration = SvgPicture.asset(
      widget.illustrationAsset!,
      width: 140,
      height: 140,
    );

    if (reduceMotion) return illustration;

    return illustration
        .animate()
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.0, 1.0),
          duration: 500.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 300.ms);
  }

  Widget _buildTitle(bool reduceMotion) {
    final title = Text(
      widget.title,
      textAlign: TextAlign.center,
      style: GoogleFonts.nunito(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: -0.5,
      ),
    );

    if (reduceMotion) return title;

    return title
        .animate()
        .fadeIn(duration: 300.ms, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1.0, 1.0),
          duration: 300.ms,
          curve: Curves.easeOut,
        );
  }

  Widget _buildSubtitle(bool reduceMotion) {
    final subtitle = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        widget.subtitle,
        textAlign: TextAlign.center,
        style: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _CelebrationColors.softCream,
        ),
      ),
    );

    if (reduceMotion) return subtitle;

    return subtitle
        .animate(delay: 200.ms)
        .fadeIn(duration: 300.ms, curve: Curves.easeOut);
  }

  /// Draws a small star-shaped confetti particle.
  Path _drawStar(Size size) {
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = size.width / 2;
    final innerR = outerR * 0.4;
    const points = 5;

    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = (pi / points) * i - pi / 2;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }
}
