import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';

/// Read-only bottom sheet displaying a walker's reviews.
///
/// Shows the average star rating at the top and a scrollable list of
/// individual reviews with reviewer name, star count, optional comment,
/// and date. Displays 'No reviews yet' when the list is empty.
class ReviewListBottomSheet extends StatelessWidget {
  const ReviewListBottomSheet({
    super.key,
    required this.reviews,
    required this.averageRating,
    required this.reviewCount,
  });

  /// List of review maps from Supabase, each containing:
  /// - `rating` (int)
  /// - `comment` (String?)
  /// - `created_at` (String ISO 8601)
  /// - `users` (Map with `full_name`?) — joined reviewer data
  final List<Map<String, dynamic>> reviews;

  /// Pre-computed average rating for the header display.
  final double averageRating;

  /// Total number of reviews.
  final int reviewCount;

  String _formatDate(String? isoString) {
    if (isoString == null) return '';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    final local = dt.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.gray300,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Header with average rating
          _buildHeader(),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.border),
          // Reviews list or empty state
          if (reviews.isEmpty)
            _buildEmptyState()
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                itemCount: reviews.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: AppSpacing.lg, color: AppColors.border),
                itemBuilder: (_, index) => _buildReviewItem(reviews[index]),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Icon(
            PhosphorIcons.star(PhosphorIconsStyle.fill),
            size: 28,
            color: AppColors.amber500,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            averageRating > 0 ? averageRating.toStringAsFixed(1) : '-',
            style: GoogleFonts.nunito(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            reviewCount == 1 ? '(1 review)' : '($reviewCount reviews)',
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            'Reviews',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.star(),
            size: 48,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No reviews yet',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Reviews from dog owners will appear here after walks.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final comment = review['comment'] as String?;
    final createdAt = review['created_at'] as String?;
    final users = review['users'] as Map<String, dynamic>?;
    final reviewerName = users?['full_name'] as String? ?? 'Anonymous';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Reviewer name
            Expanded(
              child: Text(
                reviewerName,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Date
            if (createdAt != null)
              Text(
                _formatDate(createdAt),
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // Stars
        Row(
          children: List.generate(5, (i) {
            return Icon(
              i < rating
                  ? PhosphorIcons.star(PhosphorIconsStyle.fill)
                  : PhosphorIcons.star(),
              size: 16,
              color: i < rating ? AppColors.amber500 : AppColors.gray300,
            );
          }),
        ),
        // Comment (if any)
        if (comment != null && comment.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            comment,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
