import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_theme.dart';

/// Top-of-page card on the walker profile screen.
///
/// Renders the walker's avatar (or initials fallback), name, rating +
/// total-walks chip, optional Verified badge, and optional distance pill.
/// Replaces the old `_buildProfileHeader` in walker_profile_screen.dart
/// with the cleaner KOBI-inspired card layout from the plan's references.
class WalkerHeroCard extends StatelessWidget {
  const WalkerHeroCard({
    super.key,
    required this.name,
    required this.rating,
    required this.totalWalks,
    required this.isVerified,
    this.avatarUrl,
    this.distanceKm,
  });

  final String name;

  /// `null` when the walker has no completed walks yet — renders as "New".
  final double? rating;

  final int totalWalks;
  final bool isVerified;
  final String? avatarUrl;
  final double? distanceKm;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          _Avatar(name: name, initials: _initials, avatarUrl: avatarUrl),
          const SizedBox(height: AppSpacing.md),
          Text(
            name.isEmpty ? '—' : name,
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Rating + total walks pill.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.center,
            children: [
              _RatingPill(rating: rating, totalWalks: totalWalks),
              if (isVerified) const _VerifiedPill(),
              if (distanceKm != null) _DistancePill(km: distanceKm!),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.initials,
    this.avatarUrl,
  });

  final String name;
  final String initials;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.orange400, AppColors.orange500],
        ),
        shape: BoxShape.circle,
      ),
      child: avatarUrl != null
          ? ClipOval(
              child: Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(child: _InitialsText(initials)),
              ),
            )
          : Center(child: _InitialsText(initials)),
    );
  }
}

class _InitialsText extends StatelessWidget {
  const _InitialsText(this.initials);
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Text(
      initials,
      style: GoogleFonts.nunito(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating, required this.totalWalks});
  final double? rating;
  final int totalWalks;

  @override
  Widget build(BuildContext context) {
    final ratingText = rating == null ? 'New' : rating!.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.orange50,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.star(PhosphorIconsStyle.fill),
            size: 14,
            color: AppColors.orange500,
          ),
          const SizedBox(width: 4),
          Text(
            ratingText,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            ' · $totalWalks walks',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedPill extends StatelessWidget {
  const _VerifiedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.green100,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
            size: 14,
            color: AppColors.green600,
          ),
          const SizedBox(width: 4),
          Text(
            'Verified',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.green700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistancePill extends StatelessWidget {
  const _DistancePill({required this.km});
  final double km;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.blue100,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
            size: 14,
            color: AppColors.blue500,
          ),
          const SizedBox(width: 4),
          Text(
            '${km.toStringAsFixed(km < 10 ? 1 : 0)} km',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.blue700,
            ),
          ),
        ],
      ),
    );
  }
}
