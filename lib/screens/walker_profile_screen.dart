import 'package:flutter/material.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/services/analytics_service.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';
import 'package:pawgo/widgets/walker_book_bar.dart';
import 'package:pawgo/widgets/walker_hero_card.dart';
import 'package:pawgo/widgets/walker_price_card.dart';
import 'package:pawgo/widgets/walker_stat_chip.dart';

class WalkerProfileScreen extends StatefulWidget {
  const WalkerProfileScreen({super.key});

  @override
  State<WalkerProfileScreen> createState() => _WalkerProfileScreenState();
}

class _WalkerProfileScreenState extends State<WalkerProfileScreen> {
  Map<String, dynamic>? _walker;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading && _walker == null && _error == null) {
      _fetchWalkerData();
    }
  }

  Future<void> _fetchWalkerData() async {
    final walkerId = ModalRoute.of(context)?.settings.arguments as String?;
    if (walkerId == null) {
      setState(() {
        _error = 'No walker ID provided';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;

      final walkerResponse = await withRetry(() => supabase
          .from('walkers')
          .select(
              'id, user_id, bio, experience_years, hourly_rate_mxn, background_checked, is_enabled, avg_rating, total_walks, users(full_name, avatar_url)')
          .eq('id', walkerId)
          .single());

      final reviewsResponse = await withRetry(() => supabase
          .from('reviews')
          .select(
              'id, rating, comment, created_at, reviewer_id, users(full_name, avatar_url)')
          .eq('walker_id', walkerId)
          .order('created_at', ascending: false));

      if (mounted) {
        setState(() {
          _walker = walkerResponse;
          _reviews = List<Map<String, dynamic>>.from(reviewsResponse);
          _isLoading = false;
        });
        AnalyticsService.instance.walkerProfileViewed(walkerId);
      }
    } catch (e) {
      if (mounted) {
        final appError = AppError.from(e);
        if (appError.isAuthError) {
          ErrorHandler.instance.navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/', (route) => false);
          return;
        }
        setState(() {
          _error = appError.isNetworkError
              ? 'No internet connection'
              : 'Failed to load walker profile';
          _isLoading = false;
        });
      }
    }
  }

  String _walkerName() {
    final users = _walker?['users'];
    if (users is Map) return users['full_name'] ?? 'Walker';
    return 'Walker';
  }

  String? _walkerAvatarUrl() {
    final users = _walker?['users'];
    if (users is Map) return users['avatar_url'] as String?;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hourlyRate = (_walker?['hourly_rate_mxn'] as num?)?.toDouble() ?? 0;
    final canBook = !_isLoading && _error == null && _walker != null;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Container(
              color: AppColors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(PhosphorIcons.arrowLeft(),
                          size: 20, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Walker Profile',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: PawProgressIndicator())
                  : _error != null
                      ? _buildErrorState()
                      : _buildContent(),
            ),
          ],
        ),
      ),
      // Sticky Book CTA — only enabled once walker data is loaded.
      bottomNavigationBar: WalkerBookBar(
        hourlyRateMxn: hourlyRate,
        onBook: canBook
            ? () {
                Navigator.pushNamed(context, '/booking', arguments: {
                  'walker_id': _walker?['id'],
                  'walker': _walker,
                });
              }
            : null,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.warningCircle(),
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _fetchWalkerData();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.orange500,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfileHeader(),
          const SizedBox(height: AppSpacing.md),
          _buildStatsRow(),
          const SizedBox(height: AppSpacing.md),
          _buildVerificationSection(),
          const SizedBox(height: AppSpacing.md),
          WalkerPriceCard(
            hourlyRateMxn: (_walker?['hourly_rate_mxn'] as num?)?.toDouble() ?? 0,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildAboutSection(),
          const SizedBox(height: AppSpacing.md),
          _buildReviewsSection(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final verificationStatus =
        _walker?['verification_status'] as String? ?? 'not_started';
    return WalkerHeroCard(
      name: _walkerName(),
      avatarUrl: _walkerAvatarUrl(),
      rating: (_walker?['avg_rating'] as num?)?.toDouble(),
      totalWalks: (_walker?['total_walks'] as num?)?.toInt() ?? 0,
      isVerified: verificationStatus == 'verified',
    );
  }

  /// Row of stat chips under the hero — total walks, experience, and
  /// verification status. Distance is intentionally omitted here because
  /// the profile screen doesn't have access to the owner's search origin
  /// (the Walker model from fetchWalkerById doesn't include distance_km).
  Widget _buildStatsRow() {
    final totalWalks = (_walker?['total_walks'] as num?)?.toInt() ?? 0;
    final experienceYears =
        (_walker?['experience_years'] as num?)?.toInt() ?? 0;
    final backgroundChecked = _walker?['background_checked'] == true;

    return Row(
      children: [
        Expanded(
          child: WalkerStatChip(
            icon: PhosphorIcons.pawPrint(PhosphorIconsStyle.fill),
            value: '$totalWalks',
            label: 'Walks',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: WalkerStatChip(
            icon: PhosphorIcons.briefcase(PhosphorIconsStyle.fill),
            value:
                experienceYears > 0 ? '$experienceYears yr${experienceYears != 1 ? 's' : ''}' : 'New',
            label: 'Experience',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: WalkerStatChip(
            icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
            value: backgroundChecked ? 'Yes' : 'No',
            label: 'Bg check',
            iconColor:
                backgroundChecked ? AppColors.green600 : AppColors.gray400,
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationSection() {
    final backgroundChecked = _walker?['background_checked'] == true;
    final verificationStatus =
        _walker?['verification_status'] as String? ?? 'not_started';
    final isIdVerified = verificationStatus == 'verified';

    // If nothing is verified, the section has no useful content — hide it
    // entirely instead of rendering an empty card.
    if (!backgroundChecked && !isIdVerified) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verification & Trust',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (isIdVerified) ...[
              const _VerificationBadge(
                icon: Icons.verified_user,
                iconColor: Colors.white,
                bgColor: AppColors.green500,
                gradientColors: [AppColors.green50, Color(0xFFECFDF5)],
                title: 'ID Verified',
                subtitle: 'Identity confirmed via Veriff',
                checkColor: AppColors.green600,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (backgroundChecked)
              _VerificationBadge(
                icon: PhosphorIcons.shield(PhosphorIconsStyle.fill),
                iconColor: Colors.white,
                bgColor: AppColors.green500,
                gradientColors: const [AppColors.green50, Color(0xFFECFDF5)],
                title: 'Background Check Verified',
                subtitle: 'Background check cleared',
                checkColor: AppColors.green600,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    final bio = _walker?['bio'] as String?;
    if (bio == null || bio.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              bio,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF666666),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    final rating = (_walker?['avg_rating'] as num?)?.toDouble();

    return Card(
      elevation: 0,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reviews (${_reviews.length})',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (rating != null)
                  Row(
                    children: [
                      Icon(PhosphorIcons.star(PhosphorIconsStyle.fill),
                          size: 18, color: AppColors.orange500),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_reviews.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  'No reviews yet',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ..._reviews.map((review) => _ReviewCard(review: review)),
          ],
        ),
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final List<Color> gradientColors;
  final String title;
  final String subtitle;
  final Color checkColor;

  const _VerificationBadge({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.gradientColors,
    required this.title,
    required this.subtitle,
    required this.checkColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
          Icon(PhosphorIcons.check(), color: checkColor, size: 20),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ReviewCard({required this.review});

  String _reviewerName() {
    final users = review['users'];
    if (users is Map) return users['full_name'] ?? 'Anonymous';
    return 'Anonymous';
  }

  String _reviewerInitial() {
    final name = _reviewerName();
    return name.isNotEmpty ? name[0].toUpperCase() : 'A';
  }

  String _timeAgo() {
    final createdAt = review['created_at'] as String?;
    if (createdAt == null) return '';
    try {
      final date = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} months ago';
      if (diff.inDays > 0) return '${diff.inDays} days ago';
      if (diff.inHours > 0) return '${diff.inHours} hours ago';
      return 'Just now';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final comment = review['comment'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.only(bottom: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderLight)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.blue400, AppColors.blue500],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _reviewerInitial(),
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _reviewerName(),
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (i) => Icon(
                          PhosphorIcons.star(PhosphorIconsStyle.fill),
                          size: 12,
                          color: i < rating
                              ? AppColors.orange500
                              : AppColors.gray300,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(),
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      comment,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF666666),
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
