import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A reusable card with press-to-deepen shadow micro-interaction.
///
/// On press: shadow offset increases and opacity deepens.
/// On release: reverts to normal shadow.
class PawgoCard extends StatefulWidget {
  const PawgoCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  @override
  State<PawgoCard> createState() => _PawgoCardState();
}

class _PawgoCardState extends State<PawgoCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).accessibleNavigation;
    final shadow = _isPressed && !reduceMotion
        ? AppShadows.cardPressed
        : AppShadows.card;

    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.onTap != null
          ? (_) {
              setState(() => _isPressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(AppRadius.card),
          boxShadow: shadow,
        ),
        child: widget.child,
      ),
    );
  }
}
