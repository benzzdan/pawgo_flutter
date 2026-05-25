import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../widgets/big_role_button.dart';

/// First screen a fresh (or signed-out / not-yet-onboarded) user sees.
///
/// Style follows the KOBI welcome reference: single landing screen with logo,
/// tagline, illustrated hero, two role buttons (owner filled, walker
/// outlined), and a "Log In" link for returning users.
///
/// Tapping a role button pushes `/signup` with the chosen role in arguments,
/// so the sign-up screen can route to the correct onboarding path on success.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _onRolePicked(BuildContext context, Role role) {
    Navigator.pushNamed(
      context,
      '/signup',
      arguments: {'role': role == Role.owner ? 'owner' : 'walker'},
    );
  }

  void _onLoginPressed(BuildContext context) {
    Navigator.pushNamed(context, '/login');
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
              // Wordmark (placeholder until brand PNG ships).
              Center(
                child: Text(
                  'Pawgo',
                  style: GoogleFonts.nunito(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: AppColors.cacaoBrown,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Tagline. ES first since Mexico is the primary market.
              Center(
                child: Text(
                  key: const Key('welcomeTagline'),
                  'Tu paseador de confianza.\n'
                  'Trusted dog walkers in your neighborhood.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Hero illustration.
              SizedBox(
                height: 240,
                child: SvgPicture.asset(
                  'lib/assets/illustrations/welcome_hero.svg',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // "You are a dog…" prompt.
              Center(
                child: Text(
                  'Tú eres / You are a dog:',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Owner (filled) role button.
              BigRoleButton(
                key: const Key('welcomeOwnerButton'),
                role: Role.owner,
                label: 'OWNER',
                onPressed: (r) => _onRolePicked(context, r),
              ),
              const SizedBox(height: AppSpacing.md),
              // Walker (outlined) role button.
              BigRoleButton(
                key: const Key('welcomeWalkerButton'),
                role: Role.walker,
                label: 'Walker',
                onPressed: (r) => _onRolePicked(context, r),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Log-in link for returning users.
              Center(
                child: TextButton(
                  key: const Key('welcomeLoginLink'),
                  onPressed: () => _onLoginPressed(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('\u{1F44B}'), // waving hand
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Iniciar sesión / Log In',
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.orange500,
                        ),
                      ),
                    ],
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
