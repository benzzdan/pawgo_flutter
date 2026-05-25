import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Status of a permission shown on the permissions-priming screen.
///
/// Drives the colored pill on the right-hand side of [PermissionCard].
enum PermissionCardStatus { notYet, granted, denied }

/// A card explaining WHY Pawgo needs a particular OS permission, with an
/// "Allow" CTA that drives the underlying OS prompt and a status pill that
/// reflects the current grant.
///
/// Used twice on the permissions-priming screen: once for location, once for
/// notifications. The card's content is locale-driven so callers (the screen)
/// own the i18n.
class PermissionCard extends StatelessWidget {
  const PermissionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.status,
    required this.onAllow,
    required this.allowLabel,
  });

  final IconData icon;
  final String title;
  final String body;
  final PermissionCardStatus status;

  /// Called when the user taps the Allow CTA. The screen is responsible for
  /// invoking the actual permission API (Geolocator / NotificationService)
  /// and re-rendering this card with the new [status].
  final VoidCallback onAllow;

  /// Localized label for the Allow button (e.g. "Allow location" /
  /// "Permitir ubicación").
  final String allowLabel;

  // -------------------------------------------------------------------------
  // Status pill styling. Colors are deliberately picked to land in the
  // green / red HSV families so the widget tests can sanity-check them.
  // -------------------------------------------------------------------------

  static const _pillNotYetColor = Color(0xFFE5E5E5);
  static const _pillNotYetText = Color(0xFF6F6F6F);
  static const _pillGrantedColor = Color(0xFFD1FADF); // green-ish
  static const _pillGrantedText = Color(0xFF166534);
  static const _pillDeniedColor = Color(0xFFFEE2E2); // red-ish
  static const _pillDeniedText = Color(0xFFB91C1C);

  ({Color background, Color foreground, String label, Key key}) get _pillStyle {
    switch (status) {
      case PermissionCardStatus.notYet:
        return (
          background: _pillNotYetColor,
          foreground: _pillNotYetText,
          label: 'Not yet',
          key: const Key('permissionCardPill_notYet'),
        );
      case PermissionCardStatus.granted:
        return (
          background: _pillGrantedColor,
          foreground: _pillGrantedText,
          label: 'Granted',
          key: const Key('permissionCardPill_granted'),
        );
      case PermissionCardStatus.denied:
        return (
          background: _pillDeniedColor,
          foreground: _pillDeniedText,
          label: 'Denied',
          key: const Key('permissionCardPill_denied'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pill = _pillStyle;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.orange50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.orange500, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                key: pill.key,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: pill.background,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  pill.label,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: pill.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          // Hide the Allow CTA once permission is already granted — the
          // priming screen still shows the card for confirmation but there's
          // nothing more for the user to do here.
          if (status != PermissionCardStatus.granted) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAllow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange500,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  allowLabel,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
