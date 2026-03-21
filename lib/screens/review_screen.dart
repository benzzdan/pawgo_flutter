import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/services/ad_service.dart';
import 'package:pawgo/services/analytics_service.dart';
import 'package:google_fonts/google_fonts.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _supabase = Supabase.instance.client;
  final _commentController = TextEditingController();

  String? _bookingId;
  String? _walkerId;
  String? _walkerName;
  int _rating = 0;
  bool _isSubmitting = false;
  bool _submitted = false;
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    AdService.instance.loadInterstitialAd(
      onLoaded: (ad) {
        _interstitialAd = ad;
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bookingId != null) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _bookingId = args['booking_id'] as String?;
      _walkerId = args['walker_id'] as String?;
      _walkerName = args['walker_name'] as String?;
    }
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: AppColors.orange500,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null || _bookingId == null || _walkerId == null) {
        throw Exception('Missing required data');
      }

      final comment = _commentController.text.trim();

      await _supabase.from('reviews').insert({
        'booking_id': _bookingId,
        'reviewer_id': userId,
        'walker_id': _walkerId,
        'rating': _rating,
        if (comment.isNotEmpty) 'comment': comment,
      });

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitted = true;
      });
      AnalyticsService.instance.reviewSubmitted(
        bookingId: _bookingId!,
        rating: _rating,
      );

      // Show interstitial ad for free-tier users, then navigate back
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (_interstitialAd != null) {
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              AnalyticsService.instance.adDismissed(adType: 'interstitial');
              if (mounted) Navigator.pop(context);
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              if (mounted) Navigator.pop(context);
            },
          );
          _interstitialAd!.show();
          _interstitialAd = null;
        } else {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      AnalyticsService.instance.errorOccurred(
        errorCode: 'review_error',
        message: e.toString(),
        screen: 'review',
      );
      final message = e.toString().contains('duplicate')
          ? 'You have already reviewed this walk'
          : 'Failed to submit review: $e';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Rate Your Walk',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _submitted ? _buildSuccessState() : _buildReviewForm(),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.green50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.check_circle, size: 48, color: AppColors.green600),
            ),
            const SizedBox(height: 24),
            Text(
              'Thank You!',
              style: GoogleFonts.nunito(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your review has been submitted.',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          // Walker avatar placeholder
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.orange400, AppColors.orange500],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Icon(Icons.person, size: 40, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'How was your walk with',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _walkerName ?? 'your walker',
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          // Star rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starNum = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = starNum),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    starNum <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 48,
                    color: starNum <= _rating ? AppColors.amber500 : AppColors.gray300,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            _ratingLabel(),
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _rating > 0 ? AppColors.amber500 : AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 32),
          // Comment field
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Leave a comment (optional)',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 500,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Share your experience...',
                hintStyle: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
                counterStyle: GoogleFonts.nunito(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Submit button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange500,
                disabledBackgroundColor: AppColors.orange500.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: AppColors.orange500.withValues(alpha: 0.3),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Submit Review',
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          // Skip button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Skip for now',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel() {
    switch (_rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Great';
      case 5:
        return 'Excellent!';
      default:
        return 'Tap a star to rate';
    }
  }
}
