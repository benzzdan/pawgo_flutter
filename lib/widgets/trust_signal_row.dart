import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// A single row of a "what we promise" trust signal list.
///
/// Used on `/owner-offerings` to show prospective owners the value-prop
/// before they commit to creating an account ("vet approved",
/// "background checked", "identity verified"). Each row pairs an icon
/// with bilingual labels stacked vertically — ES on top, EN below — so
/// the row reads correctly in both languages without locale switching.
///
/// Mirrors the inline-bilingual pattern used elsewhere in PR A (e.g.
/// `welcome_screen.dart` taglines) rather than introducing ARB churn.
class TrustSignalRow extends StatelessWidget {
  const TrustSignalRow({
    super.key,
    required this.icon,
    required this.labelEs,
    required this.labelEn,
    this.iconColor,
  });

  /// Glyph rendered at the start of the row — typically a checkmark.
  final IconData icon;

  /// Spanish label. Rendered on top.
  final String labelEs;

  /// English label. Rendered below the ES label in a lighter weight.
  final String labelEn;

  /// Optional override for the icon color. Defaults to [AppColors.warmCaramel]
  /// to sit harmoniously on the warm-pink onboarding background.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.warmCaramel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                labelEs,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.cacaoBrown,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                labelEn,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
