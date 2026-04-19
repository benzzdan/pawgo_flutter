import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';

/// Button variants for the Pawgo design system.
enum PawgoButtonVariant { primary, secondary, destructive, text }

/// A reusable full-width button matching the Pawgo design system.
///
/// Supports [primary] (filled orange), [secondary] (outlined orange),
/// [destructive] (filled red), and [text] (no background) variants.
class PawgoButton extends StatefulWidget {
  const PawgoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PawgoButtonVariant.primary,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final PawgoButtonVariant variant;
  final bool isLoading;
  final IconData? icon;

  @override
  State<PawgoButton> createState() => _PawgoButtonState();
}

class _PawgoButtonState extends State<PawgoButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeInOut,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  void _onTapDown(TapDownDetails _) {
    if (_isEnabled) _scaleController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _scaleController.reverse();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: Opacity(
        opacity: _isEnabled ? 1.0 : 0.5,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: _buildButton(theme),
        ),
      ),
    );
  }

  Widget _buildButton(ThemeData theme) {
    return switch (widget.variant) {
      PawgoButtonVariant.primary => _buildPrimary(theme),
      PawgoButtonVariant.secondary => _buildSecondary(theme),
      PawgoButtonVariant.destructive => _buildDestructive(theme),
      PawgoButtonVariant.text => _buildText(theme),
    };
  }

  Widget _buildPrimary(ThemeData theme) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ElevatedButton(
        onPressed: _isEnabled ? widget.onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange500,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        child: _buildContent(AppColors.white),
      ),
    );
  }

  Widget _buildSecondary(ThemeData theme) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: OutlinedButton(
        onPressed: _isEnabled ? widget.onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.orange500,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          side: const BorderSide(color: AppColors.orange500, width: 1.5),
        ),
        child: _buildContent(AppColors.orange500),
      ),
    );
  }

  Widget _buildDestructive(ThemeData theme) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ElevatedButton(
        onPressed: _isEnabled ? widget.onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.red500,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        child: _buildContent(AppColors.white),
      ),
    );
  }

  Widget _buildText(ThemeData theme) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: TextButton(
        onPressed: _isEnabled ? widget.onPressed : null,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.orange500,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        child: _buildContent(AppColors.orange500),
      ),
    );
  }

  Widget _buildContent(Color foregroundColor) {
    if (widget.isLoading) {
      return PawProgressIndicator(size: 24, strokeWidth: 2.5, color: foregroundColor);
    }

    if (widget.icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 20),
          const SizedBox(width: 8),
          Text(widget.label),
        ],
      );
    }

    return Text(widget.label);
  }
}
