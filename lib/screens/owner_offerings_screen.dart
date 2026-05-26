import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/trust_signal_row.dart';

/// Value-proposition screen between `/welcome` (owner tap) and `/signup`.
///
/// New in PR C — softens the previously abrupt "I'm an Owner → sign up
/// form" jump with a brand pitch that explains *what* an owner is signing
/// up for: vet approved, background checked, identity verified caregivers
/// in their living area. The Connect CTA continues to `/signup` carrying
/// the owner role.
///
/// Style notes:
/// - Background uses [AppColors.onboardingAccent] (shared warm-pink) so
///   the screen visually connects to the post-onboarding
///   `/finding-walkers` loader, reinforcing the brand voice.
/// - Bilingual labels follow the inline ES/EN pattern from PR A
///   (`welcome_screen.dart`) — no ARB churn for V1.
/// - The hero is a geometric SVG placeholder pending designer artwork
///   (see `lib/assets/illustrations/offerings_hero.svg`) — the screen
///   degrades cleanly to the placeholder until the real asset ships.
class OwnerOfferingsScreen extends StatelessWidget {
  const OwnerOfferingsScreen({super.key});

  void _onConnect(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/signup',
      arguments: const {'role': 'owner'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.onboardingAccent,
      appBar: AppBar(
        backgroundColor: AppColors.onboardingAccent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: BackButton(
          color: AppColors.cacaoBrown,
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero illustration. TODO(designer): replace with
                    // commissioned artwork; geometric placeholder reads as a
                    // soft circle stack for now.
                    Center(
                      child: _OfferingsHeroPlaceholder(
                        key: const Key('ownerOfferingsHero'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Headline — "We bring you:" framing.
                    Text(
                      'Te traemos:\nWe bring you:',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.cacaoBrown,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // The three trust signals.
                    TrustSignalRow(
                      icon: PhosphorIcons.check(PhosphorIconsStyle.bold),
                      labelEs: 'Aprobados por veterinario',
                      labelEn: 'Vet approved',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TrustSignalRow(
                      icon: PhosphorIcons.check(PhosphorIconsStyle.bold),
                      labelEs: 'Con verificación de antecedentes',
                      labelEn: 'Background checked',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TrustSignalRow(
                      icon: PhosphorIcons.check(PhosphorIconsStyle.bold),
                      labelEs: 'Identidad verificada',
                      labelEn: 'Identity verified',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Body copy — explains who's coming to their door.
                    Text(
                      'Cuidadores, entrenadores y especialistas '
                      'en comportamiento en tu zona.\n\n'
                      'Caregivers, trainers and behaviorists '
                      'in your living area.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Sticky bottom CTA.
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('ownerOfferingsConnectCta'),
                    onPressed: () => _onConnect(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cacaoBrown,
                      foregroundColor: AppColors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      'Conectar / Connect',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
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

/// Geometric placeholder hero used until a designer asset is commissioned.
/// Renders as three nested rounded paw-print silhouettes in the brand
/// palette — recognizable, but obviously temporary.
class _OfferingsHeroPlaceholder extends StatelessWidget {
  const _OfferingsHeroPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.warmCaramel.withValues(alpha: 0.18),
            ),
          ),
          // Middle ring
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.warmCaramel.withValues(alpha: 0.30),
            ),
          ),
          // Inner — phosphor paw, brand caramel
          Icon(
            PhosphorIcons.pawPrint(PhosphorIconsStyle.fill),
            color: AppColors.cacaoBrown,
            size: 90,
          ),
        ],
      ),
    );
  }
}
