import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/widgets/pawgo_button.dart';

/// Shows the End Walk confirmation modal. Resolves to `true` if the user
/// confirms, `false` if they cancel, or `null` if the sheet is dismissed
/// by drag or scrim tap.
Future<bool?> showEndWalkConfirmSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _EndWalkConfirmSheet(),
  );
}

class _EndWalkConfirmSheet extends StatelessWidget {
  const _EndWalkConfirmSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'End Walk?',
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to end this walk?',
              style: GoogleFonts.nunito(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            PawgoButton(
              label: 'End Walk',
              variant: PawgoButtonVariant.destructive,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 12),
            PawgoButton(
              label: 'Cancel',
              variant: PawgoButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
