import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_theme.dart';

/// Sticky bottom CTA bar for the walker profile screen.
///
/// Lives in the screen's `bottomNavigationBar` slot so it pins to the
/// bottom of the viewport regardless of scroll position. Renders the
/// hourly rate on the left as a quick reminder and a green "Book a walk"
/// elevated button on the right.
///
/// The widget has its own top-edge shadow so the bar visually separates
/// from the scrolling content above. Passing `onBook = null` disables the
/// button — useful for screens where booking isn't yet possible
/// (e.g. still loading walker data).
class WalkerBookBar extends StatelessWidget {
  const WalkerBookBar({
    super.key,
    required this.hourlyRateMxn,
    required this.onBook,
  });

  final double hourlyRateMxn;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '\$${hourlyRateMxn.round()} MXN',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'per hour',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onBook,
                icon: Icon(PhosphorIcons.calendarBlank(), size: 18),
                label: Text(
                  'Book a walk',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green600,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
