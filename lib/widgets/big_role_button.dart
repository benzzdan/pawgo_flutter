import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The two role buckets the welcome screen lets a new user pick from.
enum Role { owner, walker }

/// A large, prominent role-picker button used on the welcome screen.
///
/// Two visual variants drive both color and shape:
/// - [Role.owner] → filled with the primary brand orange ([AppColors.orange500]).
/// - [Role.walker] → outlined, transparent fill, brand-colored border.
///
/// The button is full-width inside its parent (callers usually wrap it in a
/// SizedBox/Padding) and always meets the 48 px tap-target minimum the rest
/// of the design system enforces.
class BigRoleButton extends StatelessWidget {
  const BigRoleButton({
    super.key,
    required this.role,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  /// Which role this button represents — drives the visual variant.
  final Role role;

  /// Display text inside the button.
  final String label;

  /// Tap callback. Receives the [role] so callers can hand a single handler
  /// to both buttons. Null disables the button (mirrors [ElevatedButton]).
  final ValueChanged<Role>? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  bool get _isFilled => role == Role.owner;

  Color get _fillColor =>
      _isFilled ? AppColors.orange500 : Colors.transparent;

  Color get _foregroundColor =>
      _isFilled ? AppColors.white : AppColors.orange500;

  Border? get _border => _isFilled
      ? null
      : Border.all(color: AppColors.orange500, width: 2);

  Key get _decorationKey => _isFilled
      ? const Key('bigRoleButton_owner_fill')
      : const Key('bigRoleButton_walker_outline');

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;

    return InkWell(
      onTap: isDisabled ? null : () => onPressed!(role),
      borderRadius: BorderRadius.circular(28),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          key: _decorationKey,
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: _fillColor,
            borderRadius: BorderRadius.circular(28),
            border: _border,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: _foregroundColor, size: 22),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                label,
                style: TextStyle(
                  color: _foregroundColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
