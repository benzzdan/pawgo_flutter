import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/role_service.dart';
import '../theme/app_theme.dart';

/// Owner-path landing after the permissions screen.
///
/// Single illustrated screen explaining what we'll collect about the dog,
/// with two CTAs:
/// - **Add my dog** → push `/dog-profile-form` and let that screen save.
/// - **Skip for now** → mark onboarding complete and route to `/home`.
///
/// Both branches mark `users.onboarding_completed_at` so the welcome flow
/// never re-runs for this user (the Add path's listener handles its own
/// completion when the dog form finishes; we mark it here too so a
/// user who interrupts the dog form still doesn't get re-prompted at
/// /welcome on next launch).
class DogOnboardingIntroScreen extends StatelessWidget {
  const DogOnboardingIntroScreen({
    super.key,
    Future<void> Function()? onMarkComplete,
  }) : _onMarkCompleteOverride = onMarkComplete;

  /// Test seam so widget tests don't have to mock Supabase. Defaults to
  /// [RoleService.instance.markOnboardingComplete] in production.
  final Future<void> Function()? _onMarkCompleteOverride;

  Future<void> _markComplete() async {
    if (_onMarkCompleteOverride != null) {
      await _onMarkCompleteOverride();
      return;
    }
    await RoleService.instance.markOnboardingComplete();
  }

  Future<void> _onAddMyDog(BuildContext context) async {
    // Mark onboarding complete before navigating so an interrupted dog
    // form doesn't leave the user in a re-prompt loop.
    await _markComplete();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/dog-profile-form');
  }

  Future<void> _onSkip(BuildContext context) async {
    await _markComplete();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),
              Text(
                '¡Conozcamos a tu perrito! / Let\'s meet your dog!',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.cacaoBrown,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 220,
                child: SvgPicture.asset(
                  'lib/assets/illustrations/dog_onboarding_hero.svg',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Necesitamos algunos datos para que los paseadores puedan '
                'cuidarlo: raza, peso, cartilla de vacunación, veterinario y '
                'contacto de emergencia.\n\n'
                'We ask for breed, weight, vaccination card, vet, and '
                'emergency contact so walkers can keep them safe.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('dogOnboardingAddCta'),
                  onPressed: () => _onAddMyDog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange500,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    'Agregar mi perro / Add my dog',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                key: const Key('dogOnboardingSkipCta'),
                onPressed: () => _onSkip(context),
                child: Text(
                  'Omitir por ahora / Skip for now',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
