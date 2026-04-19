import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/services/analytics_service.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';

class ReviewBottomSheet extends StatefulWidget {
  const ReviewBottomSheet({
    super.key,
    required this.bookingId,
    required this.walkerId,
    required this.walkerName,
  });

  final String bookingId;
  final String walkerId;
  final String walkerName;

  /// True once the sheet has been shown this app session.
  /// Prevents duplicate prompts. Reset to false on sign-out.
  static bool shownThisSession = false;

  @override
  State<ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends State<ReviewBottomSheet> {
  final _commentController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ErrorHandler.instance.showRecoverableError(context, 'Please select a rating');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        Navigator.pop(context);
        return;
      }
      final comment = _commentController.text.trim();
      await withRetry(() => Supabase.instance.client.from('reviews').insert({
            'booking_id': widget.bookingId,
            'reviewer_id': userId,
            'walker_id': widget.walkerId,
            'rating': _rating,
            if (comment.isNotEmpty) 'comment': comment,
          }));
      if (!mounted) return;
      AnalyticsService.instance.reviewSubmitted(
        bookingId: widget.bookingId,
        rating: _rating,
      );
      Navigator.pop(context, true); // true = successfully submitted
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final isDuplicate = e is PostgrestException && e.code == '23505';
      ErrorHandler.instance.handleError(
        context, e,
        screen: 'review_sheet',
        fallbackMessage: isDuplicate
            ? 'You have already reviewed this walk'
            : 'Failed to submit review. Please try again.',
      );
    }
  }

  void _skip() => Navigator.pop(context, false); // false = skipped

  String _ratingLabel() {
    switch (_rating) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Great';
      case 5: return 'Excellent!';
      default: return 'Tap a star to rate';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.orange400, AppColors.orange500],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(PhosphorIcons.user(), size: 32, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Text('How was your walk with',
                style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(widget.walkerName,
                style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    key: ValueKey('star_$star'),
                    onTap: () => setState(() => _rating = star),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        star <= _rating
                            ? PhosphorIcons.star(PhosphorIconsStyle.fill)
                            : PhosphorIcons.star(),
                        size: 40,
                        color: star <= _rating ? AppColors.amber500 : AppColors.gray300,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 6),
              Text(_ratingLabel(),
                style: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: _rating > 0 ? AppColors.amber500 : AppColors.textTertiary,
                )),
              const SizedBox(height: 20),
              TextField(
                controller: _commentController,
                maxLines: 3, maxLength: 500,
                style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Share your experience... (optional)',
                  hintStyle: GoogleFonts.nunito(color: AppColors.textTertiary, fontSize: 14),
                  filled: true, fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(12),
                  counterStyle: GoogleFonts.nunito(fontSize: 11, color: AppColors.textTertiary),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange500,
                    disabledBackgroundColor: AppColors.orange500.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const PawProgressIndicator(size: 20, strokeWidth: 2, color: Colors.white)
                      : Text('Submit Review',
                          style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _skip,
                child: Text('Skip for now',
                  style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
