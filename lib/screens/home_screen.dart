import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/widgets/stat_card.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pawgo/services/ad_service.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:pawgo/services/role_service.dart';
import 'package:pawgo/screens/main_shell.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _walkers = [];
  bool _loading = true;
  String? _error;
  bool _isBannerAdLoaded = false;
  final _adKey = GlobalKey();
  int _upcoming = 0;
  int _active = 0;
  int _completed = 0;
  String? _activeBookingId;
  RealtimeChannel? _bookingsChannel;
  Timer? _statsPollTimer;

  @override
  void initState() {
    super.initState();
    _fetchWalkers();
    _loadStats();
    _loadBannerAd();
    _subscribeToBookings();
    _startStatsPolling();
  }

  /// Polling fallback for when Realtime is unavailable. Refreshes booking
  /// stats every 15s so the active walk banner appears even if the
  /// realtime channel never delivers events.
  void _startStatsPolling() {
    _statsPollTimer?.cancel();
    _statsPollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _loadStats(silent: true);
    });
  }

  void _loadBannerAd() {
    if (mounted) setState(() => _isBannerAdLoaded = true);
  }

  void _subscribeToBookings() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _bookingsChannel = Supabase.instance.client
        .channel('home_bookings')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'owner_id',
            value: userId,
          ),
          callback: (payload) {
            // Re-fetch stats when any booking status changes
            _loadStats(silent: true);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _statsPollTimer?.cancel();
    _bookingsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchWalkers() async {
    try {
      final data = await withRetry(() => Supabase.instance.client
          .from('walkers')
          .select('id, user_id, bio, experience_years, hourly_rate_mxn, avg_rating, total_walks, users(full_name, avatar_url)')
          .eq('is_enabled', true)
          .order('avg_rating', ascending: false));

      if (!mounted) return;
      setState(() {
        _walkers = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      if (!mounted) return;
      final appError = AppError.from(e);
      if (appError.isAuthError) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }
      // Walkers error is non-blocking; stats may still load fine
    }
  }

  Future<void> _loadStats({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Not authenticated';
          });
        }
        return;
      }

      final bookings = await Supabase.instance.client
          .from('bookings')
          .select('id, status')
          .eq('owner_id', userId);

      final list = bookings as List;
      int upcoming = 0;
      int active = 0;
      int completed = 0;
      String? activeId;

      for (final b in list) {
        final status = b['status'] as String?;
        switch (status) {
          case 'pending':
          case 'confirmed':
          case 'walker_en_route':
            upcoming++;
          case 'walk_started':
            active++;
            activeId ??= b['id'] as String?;
          case 'walk_completed':
            completed++;
        }
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _upcoming = upcoming;
          _active = active;
          _completed = completed;
          _activeBookingId = activeId;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unable to load your dashboard. Please try again.';
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_fetchWalkers(), _loadStats()]);
  }

  String get _timeOfDay {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  String get _tip {
    switch (_timeOfDay) {
      case 'morning':
        return "Morning walks help reduce anxiety and set a positive tone for your dog's day. They'll be calmer and happier!";
      case 'afternoon':
        return "Afternoon walks are perfect for socialization! Your pup can meet new furry friends and build confidence.";
      default:
        return "Evening walks help your dog wind down and sleep better. A tired pup is a happy pup!";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _walkers.isEmpty) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting with sitting corgi companion
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/illustrations/corgi_sitting.png',
                    width: 90,
                    height: 90,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good $_timeOfDay!',
                          style: GoogleFonts.nunito(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Your pup's tail is wagging\u{2014}ready for today's adventure?",
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tip Card
            _buildTipCard(),
            const SizedBox(height: 20),

            // Stats (live from Supabase) — only for walkers
            if (RoleService.instance.activeRole.value == ActiveRole.walker)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                        children: [
                          Expanded(
                            child: StatCard(
                                icon: PhosphorIcons.calendarBlank(),
                                number: _upcoming,
                                label: 'Upcoming',
                                variant: 'blue'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                                icon: PhosphorIcons.clock(),
                                number: _active,
                                label: 'Active',
                                variant: 'green'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                                icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                                number: _completed,
                                label: 'Completed',
                                variant: 'gray'),
                          ),
                        ],
                      ),
              ),
            const SizedBox(height: 20),

            // Active Walk Banner — only when there is an active walk
            if (_active > 0) ...[
              _buildActiveWalkBanner(context),
              const SizedBox(height: 20),
            ],

            // Find a Walker Banner
            _buildFindWalkerBanner(context),
            const SizedBox(height: 20),

            // Available Walkers Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available Walkers',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      context.findAncestorStateOfType<MainShellState>()
                          ?.switchOwnerTab(1);
                    },
                    child: Text(
                      'View all',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.orange500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Walkers list from Supabase
            _buildWalkersList(),
            const SizedBox(height: 20),

            // Banner Ad (free-tier only)
            if (_isBannerAdLoaded)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _HomeBannerAd(key: _adKey),
              ),

            // Upcoming Walks
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Upcoming Walks',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      context.findAncestorStateOfType<MainShellState>()
                          ?.switchOwnerTab(2);
                    },
                    child: Text(
                      'View all',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.orange500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Empty State
            _buildEmptyState(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWalkersList() {
    if (_walkers.isEmpty && _loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_walkers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.borderDashed,
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Column(
            children: [
              Icon(PhosphorIcons.userFocus(),
                  size: 56, color: Colors.grey.withValues(alpha: 0.3)),
              const SizedBox(height: 14),
              Text(
                'No walkers available right now',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _walkers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final walker = _walkers[index];
          return _WalkerCard(walker: walker);
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.warningCircle(),
              size: 64,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadStats,
              icon: Icon(PhosphorIcons.arrowsClockwise()),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.purple50, AppColors.pink50],
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: AppColors.purple100.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.purple400, AppColors.pink400],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(PhosphorIcons.sparkle(), color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "Today's Tip",
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.purple900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill),
                          color: AppColors.pink500, size: 12),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _tip,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.purple800,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveWalkBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/active-walk',
            arguments: _activeBookingId),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.green500, AppColors.emerald400],
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: [
              BoxShadow(
                color: AppColors.green500.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background ripple circle
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              // Pulsing ripple effect behind LIVE badge
              Positioned(
                right: 20,
                top: 10,
                child: _buildPulseRipple(),
              ),
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Walk',
                          style: GoogleFonts.nunito(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(PhosphorIcons.clock(),
                                color: Colors.white70, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              '18 min \u{2022} 1.2 miles',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // LIVE badge with arrow
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        )
                            .animate(
                                onPlay: (c) =>
                                    c.repeat(reverse: true))
                            .fade(
                                begin: 1.0,
                                end: 0.3,
                                duration: 800.ms),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(PhosphorIcons.arrowRight(),
                            color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pulsing ripple rings behind the location icon.
  Widget _buildPulseRipple() {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(3, (i) {
          return Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 2,
              ),
            ),
          )
              .animate(
                  onPlay: (c) => c.repeat(),
                  delay: (i * 600).ms)
              .scaleXY(begin: 0.4, end: 1.6, duration: 1800.ms)
              .fadeOut(begin: 0.6, duration: 1800.ms);
        }),
      ),
    );
  }

  Widget _buildFindWalkerBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () {
          context.findAncestorStateOfType<MainShellState>()
              ?.switchOwnerTab(1);
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.orange500, AppColors.orange400],
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: [
              BoxShadow(
                color: AppColors.orange500.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Icon(PhosphorIcons.magnifyingGlass(), color: Colors.white, size: 26),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Find a Walker',
                          style: GoogleFonts.nunito(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Browse trusted walkers near you',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(PhosphorIcons.arrowRight(),
                        color: Colors.white, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: AppColors.borderDashed,
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          children: [
            Icon(PhosphorIcons.pawPrint(), size: 56, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 14),
            Text(
              'No upcoming walks',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalkerCard extends StatelessWidget {
  final Map<String, dynamic> walker;

  const _WalkerCard({required this.walker});

  @override
  Widget build(BuildContext context) {
    final user = walker['users'] as Map<String, dynamic>?;
    final name = user?['full_name'] as String? ?? 'Walker';
    final avatarUrl = user?['avatar_url'] as String?;
    final rating = (walker['avg_rating'] as num?)?.toDouble() ?? 0.0;
    final hourlyRate = (walker['hourly_rate_mxn'] as num?)?.toDouble() ?? 0.0;
    final experienceYears = (walker['experience_years'] as num?)?.toInt() ?? 0;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/walker', arguments: walker['id']),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.orange400, AppColors.orange500],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(PhosphorIcons.user(), color: Colors.white, size: 28),
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(PhosphorIcons.user(), color: Colors.white, size: 28),
                    ),
            ),
            const SizedBox(height: 10),
            // Name
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            // Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PhosphorIcons.star(PhosphorIconsStyle.fill), size: 14, color: AppColors.orange500),
                const SizedBox(width: 4),
                Text(
                  rating > 0 ? rating.toStringAsFixed(1) : 'New',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Experience
            Text(
              '$experienceYears yr${experienceYears != 1 ? 's' : ''} exp',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            // Price
            Text(
              '\$${hourlyRate.toStringAsFixed(0)} MXN/hr',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.orange500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Self-contained banner ad widget that manages its own ad lifecycle.
class _HomeBannerAd extends StatefulWidget {
  const _HomeBannerAd({super.key});

  @override
  State<_HomeBannerAd> createState() => _HomeBannerAdState();
}

class _HomeBannerAdState extends State<_HomeBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    final ad = AdService.instance.createBannerAd(
      onLoaded: () {
        if (mounted) setState(() => _isLoaded = true);
      },
    );
    if (ad != null) _bannerAd = ad;
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) return const SizedBox.shrink();
    return Center(
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
