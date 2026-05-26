import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/walking_dog_animation.dart';

/// Branded loading screen shown between dog-onboarding and the home dashboard
/// for fresh owners. The previously-abrupt jump from "I added (or skipped)
/// my dog" → `/home` is softened by a few seconds of Rive walking-dog
/// animation while the same walker-fetch the home screen runs primes the
/// next view.
///
/// Dismissal rule: `pushReplacementNamed('/home')` fires only after BOTH
/// the walker fetch has resolved AND a minimum-display duration has
/// elapsed — whichever happens last. This prevents the loader from
/// flashing for a few hundred milliseconds when the network is fast.
///
/// Error path: if the fetch fails, the loader does NOT auto-advance; it
/// surfaces the failure inline and offers a "Continuar / Continue" button
/// so the user can still reach `/home` (the home screen does its own
/// retry on mount).
class FindingWalkersLoaderScreen extends StatefulWidget {
  const FindingWalkersLoaderScreen({
    super.key,
    Future<void> Function()? fetchWalkers,
    Duration minDisplay = const Duration(seconds: 2),
  })  : _fetchWalkersOverride = fetchWalkers,
        _minDisplay = minDisplay;

  /// Test seam — defaults to a Supabase walker query that mirrors the home
  /// screen's `_fetchWalkers`. Overrideable for widget tests so they don't
  /// have to mock Supabase.
  final Future<void> Function()? _fetchWalkersOverride;

  /// Minimum time the loader stays visible before transitioning, even if
  /// the fetch resolves first. 2.0s is brand-tuned so the loop reads
  /// cleanly without feeling stale.
  final Duration _minDisplay;

  @override
  State<FindingWalkersLoaderScreen> createState() =>
      _FindingWalkersLoaderScreenState();
}

class _FindingWalkersLoaderScreenState
    extends State<FindingWalkersLoaderScreen> {
  late final Future<void> _fetchFuture;
  late final Future<void> _minDisplayFuture;
  bool _hasError = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _fetchFuture = _runFetch();
    _minDisplayFuture = Future<void>.delayed(widget._minDisplay);
    _waitForBoth();
  }

  Future<void> _runFetch() async {
    final override = widget._fetchWalkersOverride;
    if (override != null) {
      await override();
      return;
    }
    // Same shape as HomeScreen._fetchWalkers — primes the walker list
    // so the home dashboard renders without an extra spinner.
    await Supabase.instance.client
        .from('walkers')
        .select(
          'id, user_id, bio, experience_years, hourly_rate_mxn, '
          'avg_rating, total_walks, users(full_name, avatar_url)',
        )
        .eq('is_enabled', true)
        .eq('verification_status', 'verified')
        .order('avg_rating', ascending: false);
  }

  Future<void> _waitForBoth() async {
    try {
      // Wait for BOTH the fetch and the minimum-display delay. If either
      // is still pending we keep showing the loader. .wait short-circuits
      // on error, which is what we want.
      await Future.wait<void>([_fetchFuture, _minDisplayFuture]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _hasError = true);
      return;
    }

    _navigateToHome();
  }

  void _navigateToHome() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.onboardingAccent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _hasError ? _buildError(context) : _buildLoading(context),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Column(
      key: const Key('findingWalkersLoadingState'),
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        WalkingDogAnimation(
          size: 240,
          semanticsLabel: 'Finding walkers',
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Encontrando paseadores cerca de ti\n'
          'Finding walkers near you…',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.cacaoBrown,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Esto sólo toma un momento / Just a moment…',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return Column(
      key: const Key('findingWalkersErrorState'),
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_off_rounded,
          size: 56,
          color: AppColors.cacaoBrown.withValues(alpha: 0.7),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'No pudimos preparar tu lista — puedes continuar.\n'
          'We could not preload your list — you can continue.',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.cacaoBrown,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('findingWalkersContinueCta'),
            onPressed: () {
              // Defensively mark error consumed before navigating so the
              // double-tap path is a no-op.
              _navigateToHome();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cacaoBrown,
              foregroundColor: AppColors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Text(
              'Continuar / Continue',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

