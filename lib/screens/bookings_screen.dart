import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:pawgo/services/booking_status_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pawgo/widgets/review_bottom_sheet.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key, this.bookingStatusService});

  /// Set before navigating to bookings to open with a specific tab selected.
  /// BookingsScreen reads and clears this in initState.
  static String? pendingInitialTab;

  /// Returns true when the review-check is appropriate — i.e. the user
  /// navigated to bookings organically (bottom nav) rather than being sent
  /// here programmatically after creating a booking or submitting a review.
  /// Also returns false when the review sheet was already shown this session.
  static bool shouldCheckPendingReview() {
    if (ReviewBottomSheet.shownThisSession) return false;
    // When pendingInitialTab is set, the navigation was programmatic
    // (e.g. after booking creation or review submission) — don't interrupt.
    if (pendingInitialTab != null) return false;
    return true;
  }

  /// Optional injected service for testing.
  final BookingStatusService? bookingStatusService;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  String _selectedTab = 'upcoming';
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _channel;

  late BookingStatusService _statusService;
  StreamSubscription<BookingStatusUpdate>? _statusSub;
  StreamSubscription<BookingStatusConnectionState>? _connectionSub;
  BookingStatusConnectionState _connectionState =
      BookingStatusConnectionState.disconnected;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // Capture whether a review check is appropriate BEFORE clearing
    // pendingInitialTab — once cleared, shouldCheckPendingReview() would
    // return true even on a programmatic navigation.
    final shouldReview = BookingsScreen.shouldCheckPendingReview();
    final pending = BookingsScreen.pendingInitialTab;
    if (pending != null) {
      _selectedTab = pending;
      BookingsScreen.pendingInitialTab = null;
    }
    _statusService = widget.bookingStatusService ?? BookingStatusService();
    _fetchBookings().then((_) {
      if (_error == null && shouldReview) _checkPendingReview();
    });
    _subscribeToUpdates();
    _subscribeToStatusService();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _statusSub?.cancel();
    _connectionSub?.cancel();
    _statusService.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }
      final data = await withRetry(() => _supabase
          .from('bookings')
          .select(
              '*, walkers(id, user_id, users(full_name, avatar_url)), dogs(name, breed, photo_url)')
          .eq('owner_id', userId)
          .order('scheduled_at', ascending: false));

      if (!mounted) return;
      setState(() {
        _bookings = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final appError = AppError.from(e);
      if (appError.isAuthError) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }
      setState(() {
        _error = appError.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkPendingReview() async {
    if (ReviewBottomSheet.shownThisSession) return;
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch up to 5 most-recently-updated completed bookings for this owner
      final data = await withRetry(() => _supabase
          .from('bookings')
          .select('id, walker_id, walkers!bookings_walker_id_fkey(users(full_name))')
          .eq('owner_id', userId)
          .eq('status', 'walk_completed')
          .order('updated_at', ascending: false)
          .limit(5));

      for (final booking in (data as List)) {
        final bookingId = booking['id'] as String;

        // Check if a review already exists for this booking
        final reviews = await withRetry(() => _supabase
            .from('reviews')
            .select('id')
            .eq('booking_id', bookingId)
            .limit(1));

        if ((reviews as List).isEmpty) {
          final walkerData = booking['walkers'] as Map<String, dynamic>?;
          final userMap = walkerData?['users'] as Map<String, dynamic>?;
          final walkerId = booking['walker_id'] as String;
          final walkerName = userMap?['full_name'] as String? ?? 'your walker';

          if (!mounted) return;
          ReviewBottomSheet.shownThisSession = true;

          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (_) => ReviewBottomSheet(
              bookingId: bookingId,
              walkerId: walkerId,
              walkerName: walkerName,
            ),
          );

          if (!mounted) return;
          setState(() => _selectedTab = 'past');
          break;
        }
      }
    } catch (_) {
      // Non-critical: silently ignore errors in the review check
    }
  }

  void _subscribeToUpdates() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    _channel = _supabase.channel('bookings_owner_$userId');
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'bookings',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'owner_id',
        value: userId,
      ),
      callback: (payload) {
        final updated = payload.newRecord;
        if (!mounted) return;
        setState(() {
          final idx =
              _bookings.indexWhere((b) => b['id'] == updated['id']);
          if (idx != -1) {
            // Preserve joined data, update scalar fields
            final existing = _bookings[idx];
            _bookings[idx] = {
              ...existing,
              ...updated,
              'walkers': existing['walkers'],
              'dogs': existing['dogs'],
            };
          }
        });
      },
    );
    _channel!.subscribe();
  }

  void _subscribeToStatusService() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _connectionSub = _statusService.connectionStream.listen((state) {
      if (mounted) setState(() => _connectionState = state);
    });

    _statusService.subscribe(
      filterColumn: 'owner_id',
      filterValue: userId,
    );
  }

  List<Map<String, dynamic>> get _filteredBookings {
    switch (_selectedTab) {
      case 'upcoming':
        return _bookings.where((b) {
          final status = b['status'] as String;
          return [
            'pending',
            'pending_walker_acceptance',
            'confirmed',
            'walker_en_route',
            'walk_started'
          ].contains(status);
        }).toList();
      case 'past':
        return _bookings
            .where((b) => b['status'] == 'walk_completed')
            .toList();
      case 'cancelled':
        return _bookings.where((b) {
          final status = b['status'] as String;
          return ['cancelled', 'disputed'].contains(status);
        }).toList();
      default:
        return _bookings;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).accessibleNavigation;

    Widget illustration = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        'assets/illustrations/corgi_sitting.png',
        width: 150,
        fit: BoxFit.contain,
      ),
    );

    if (!reduceMotion) {
      illustration = illustration
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .moveY(
              begin: 0, end: -2, duration: 3000.ms, curve: Curves.easeInOut);
    }

    Widget content = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            illustration,
            const SizedBox(height: 24),
            Text(
              _selectedTab == 'upcoming'
                  ? 'No upcoming bookings'
                  : _selectedTab == 'past'
                      ? 'No past walks yet'
                      : 'No cancelled bookings',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Book a walk and your pup will thank you',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );

    if (!reduceMotion) {
      content = content
          .animate()
          .fadeIn(duration: 400.ms, curve: Curves.easeOut)
          .scale(
            begin: const Offset(0.95, 0.95),
            end: const Offset(1.0, 1.0),
            duration: 400.ms,
            curve: Curves.easeOut,
          );
    }

    return content;
  }

  Widget _buildConnectionBanner() {
    if (_connectionState == BookingStatusConnectionState.connected ||
        _connectionState == BookingStatusConnectionState.connecting) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _connectionState == BookingStatusConnectionState.error
          ? const Color(0xFFFEF2F2)
          : const Color(0xFFFFFBEB),
      child: Row(
        children: [
          Icon(
            _connectionState == BookingStatusConnectionState.error
                ? PhosphorIcons.warningCircle()
                : PhosphorIcons.wifiSlash(),
            size: 16,
            color: _connectionState == BookingStatusConnectionState.error
                ? const Color(0xFFDC2626)
                : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Live updates unavailable. Tap to refresh.',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _connectionState == BookingStatusConnectionState.error
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFF59E0B),
              ),
            ),
          ),
          GestureDetector(
            onTap: _fetchBookings,
            child: Icon(
              PhosphorIcons.arrowsClockwise(),
              size: 18,
              color: _connectionState == BookingStatusConnectionState.error
                  ? const Color(0xFFDC2626)
                  : const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Connection banner
        _buildConnectionBanner(),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Bookings',
                style: GoogleFonts.nunito(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage your upcoming walks',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // Filter Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _TabChip(
                label: 'Upcoming',
                isSelected: _selectedTab == 'upcoming',
                onTap: () => setState(() => _selectedTab = 'upcoming'),
              ),
              const SizedBox(width: 8),
              _TabChip(
                label: 'Past',
                isSelected: _selectedTab == 'past',
                onTap: () => setState(() => _selectedTab = 'past'),
              ),
              const SizedBox(width: 8),
              _TabChip(
                label: 'Cancelled',
                isSelected: _selectedTab == 'cancelled',
                onTap: () => setState(() => _selectedTab = 'cancelled'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Content
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.warningCircle(), size: 48, color: AppColors.red500),
              const SizedBox(height: 12),
              Text(
                'Failed to load bookings',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _fetchBookings,
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
                      fontSize: 14,
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

    final filtered = _filteredBookings;

    if (filtered.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: _fetchBookings,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          return _BookingCard(
            booking: filtered[index],
            onTap: () => _openBookingDetail(filtered[index]),
          );
        },
      ),
    );
  }

  void _openBookingDetail(Map<String, dynamic> booking) {
    final status = booking['status'] as String;
    final walkerData = booking['walkers'] as Map<String, dynamic>?;
    final walkerUser = walkerData?['users'] as Map<String, dynamic>?;
    final dogData = booking['dogs'] as Map<String, dynamic>?;
    final walkerName = walkerUser?['full_name'] ?? 'Walker';
    final dogName = dogData?['name'] ?? 'Dog';

    if (status == 'walk_started') {
      // Navigate to active walk / GPS tracking
      Navigator.pushNamed(context, '/active-walk', arguments: {
        'booking_id': booking['id'],
        'walker_name': walkerName,
        'dog_name': dogName,
      });
    } else if (status == 'walk_completed') {
      // Show walk summary dialog
      _showBookingDetail(booking);
    } else {
      // Show booking detail dialog for other statuses
      _showBookingDetail(booking);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchClaims(String bookingId) async {
    try {
      final data = await withRetry(() => _supabase
          .from('insurance_claims')
          .select('id, claim_type, status, amount_mxn')
          .eq('booking_id', bookingId));
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  Future<void> _cancelPendingBooking(BuildContext sheetContext, String bookingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel Request?',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text(
            'Are you sure you want to cancel this walk request?',
            style: GoogleFonts.nunito()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel Request',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    color: AppColors.red500)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await withRetry(() => _supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', bookingId));

      if (!mounted) return;
      Navigator.pop(sheetContext); // Close the detail sheet
      _fetchBookings(); // Refresh the list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Walk request cancelled',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.red500,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.instance.handleError(
        context,
        e,
        screen: 'bookings',
        fallbackMessage: 'Failed to cancel booking. Please try again.',
      );
    }
  }

  void _showBookingDetail(Map<String, dynamic> booking) {
    final walkerData = booking['walkers'] as Map<String, dynamic>?;
    final walkerUser = walkerData?['users'] as Map<String, dynamic>?;
    final dogData = booking['dogs'] as Map<String, dynamic>?;
    final walkerName = walkerUser?['full_name'] ?? 'Unknown';
    final dogName = dogData?['name'] ?? 'Unknown';
    final dogBreed = dogData?['breed'] ?? '';
    final status = booking['status'] as String;
    final scheduledAt = booking['scheduled_at'] != null
        ? DateTime.tryParse(booking['scheduled_at'])
        : null;
    final duration = booking['duration_minutes'] as int?;
    final price = (booking['total_price_mxn'] as num?)?.toDouble();
    final startedAt = booking['started_at'] != null
        ? DateTime.tryParse(booking['started_at'])
        : null;
    final completedAt = booking['completed_at'] != null
        ? DateTime.tryParse(booking['completed_at'])
        : null;

    // Pre-fetch claims for completed/disputed bookings
    final claimsFuture = (status == 'walk_completed' || status == 'disputed')
        ? _fetchClaims(booking['id'])
        : Future.value(<Map<String, dynamic>>[]);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.gray300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Status badge
              _StatusBadge(status: status),
              // Countdown timer for pending_walker_acceptance
              if (status == 'pending_walker_acceptance') ...[
                const SizedBox(height: 12),
                _CountdownBanner(
                  acceptanceDeadline: booking['acceptance_deadline'] as String?,
                ),
              ],
              const SizedBox(height: 16),
              // Walker
              Text('Walker',
                  style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(walkerName,
                  style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              // Dog
              Text('Dog',
                  style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text('$dogName${dogBreed.isNotEmpty ? ' ($dogBreed)' : ''}',
                  style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              // Scheduled time
              if (scheduledAt != null) ...[
                _DetailRow(
                  icon: PhosphorIcons.calendarBlank(),
                  iconColor: AppColors.blue600,
                  bgColor: AppColors.blue50,
                  text: DateFormat('MMM d, yyyy').format(scheduledAt),
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  icon: PhosphorIcons.clock(),
                  iconColor: AppColors.purple600,
                  bgColor: AppColors.purple50,
                  text: DateFormat('h:mm a').format(scheduledAt),
                ),
                const SizedBox(height: 10),
              ],
              // Duration
              if (duration != null)
                _DetailRow(
                  icon: PhosphorIcons.timer(),
                  iconColor: AppColors.green600,
                  bgColor: AppColors.green50,
                  text: '$duration min',
                ),
              if (duration != null) const SizedBox(height: 10),
              // Started / Completed times
              if (startedAt != null) ...[
                _DetailRow(
                  icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
                  iconColor: AppColors.green600,
                  bgColor: AppColors.green50,
                  text:
                      'Started: ${DateFormat('h:mm a').format(startedAt.toLocal())}',
                ),
                const SizedBox(height: 10),
              ],
              if (completedAt != null) ...[
                _DetailRow(
                  icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                  iconColor: AppColors.green600,
                  bgColor: AppColors.green50,
                  text:
                      'Completed: ${DateFormat('h:mm a').format(completedAt.toLocal())}',
                ),
                const SizedBox(height: 10),
              ],
              // Price
              if (price != null) ...[
                _DetailRow(
                  icon: PhosphorIcons.currencyDollar(),
                  iconColor: AppColors.orange500,
                  bgColor: AppColors.orange50,
                  text: '\$${price.toStringAsFixed(2)} MXN',
                ),
                const SizedBox(height: 16),
              ],
              // Insurance claims section
              if (status == 'walk_completed' || status == 'disputed')
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: claimsFuture,
                  builder: (context, snapshot) {
                    final claims = snapshot.data;
                    if (claims == null || claims.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text('Insurance Claims',
                            style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        ...claims.map((claim) {
                          final claimType = claim['claim_type'] as String? ?? '';
                          final claimStatus = claim['status'] as String? ?? '';
                          final amount = (claim['amount_mxn'] as num?)?.toDouble();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _claimStatusBg(claimStatus),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(PhosphorIcons.shield(PhosphorIconsStyle.fill),
                                      size: 18,
                                      color: _claimStatusColor(claimStatus)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${claimType[0].toUpperCase()}${claimType.substring(1)}${amount != null ? ' — \$${amount.toStringAsFixed(2)} MXN' : ''}',
                                      style: GoogleFonts.nunito(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _claimStatusColor(claimStatus)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      claimStatus.toUpperCase(),
                                      style: GoogleFonts.nunito(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              _claimStatusColor(claimStatus)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 6),
                      ],
                    );
                  },
                ),
              // Action buttons based on status
              if (status == 'walk_started' || status == 'confirmed') ...[
                Row(
                  children: [
                    if (status == 'walk_started')
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.pushNamed(context, '/active-walk',
                                arguments: {
                                  'booking_id': booking['id'],
                                  'walker_name': walkerName,
                                  'dog_name': dogName,
                                });
                          },
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.blue600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text('Track Walk',
                                  style: GoogleFonts.nunito(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ),
                          ),
                        ),
                      ),
                    if (status == 'walk_started') const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(context, '/chat', arguments: {
                            'booking_id': booking['id'],
                            'other_party_name': walkerName,
                          });
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.orange500,
                                AppColors.orange400
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text('Chat',
                                style: GoogleFonts.nunito(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              // Cancel button for pending_walker_acceptance bookings
              if (status == 'pending_walker_acceptance') ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _cancelPendingBooking(ctx, booking['id']),
                    icon: Icon(PhosphorIcons.xCircle(), size: 18),
                    label: Text('Cancel Request',
                        style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red500,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
              // Insurance claim button for completed or disputed walks
              if (status == 'walk_completed' || status == 'disputed') ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, '/insurance-claim',
                          arguments: {
                            'booking_id': booking['id'],
                          });
                    },
                    icon: Icon(PhosphorIcons.shield(PhosphorIconsStyle.fill), size: 18),
                    label: Text('File Insurance Claim',
                        style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.orange500,
                      side: const BorderSide(
                          color: AppColors.orange500, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Color _claimStatusColor(String status) {
  switch (status) {
    case 'open':
      return AppColors.blue600;
    case 'reviewing':
      return AppColors.amber500;
    case 'approved':
      return AppColors.green600;
    case 'rejected':
      return AppColors.red500;
    default:
      return AppColors.textSecondary;
  }
}

Color _claimStatusBg(String status) {
  switch (status) {
    case 'open':
      return AppColors.blue50;
    case 'reviewing':
      return AppColors.amber50;
    case 'approved':
      return AppColors.green50;
    case 'rejected':
      return AppColors.red50;
    default:
      return AppColors.gray100;
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.orange500 : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? null
              : Border.all(color: AppColors.border, width: 2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.orange500.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _statusConfig(status);
    final reduceMotion = MediaQuery.of(context).accessibleNavigation;
    final isPending = status == 'pending_walker_acceptance';

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPending) ...[
            _PulsingDot(color: config.textColor, animate: !reduceMotion),
            const SizedBox(width: 6),
          ],
          Text(
            config.label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: config.textColor,
            ),
          ),
        ],
      ),
    );

    return badge;
  }
}

/// Small pulsing dot indicator for pending_walker_acceptance status.
class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool animate;

  const _PulsingDot({required this.color, this.animate = true});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

class _StatusConfig {
  final String label;
  final Color bgColor;
  final Color textColor;
  const _StatusConfig(this.label, this.bgColor, this.textColor);
}

_StatusConfig _statusConfig(String status) {
  switch (status) {
    case 'pending':
      return _StatusConfig('Pending', AppColors.amber50, AppColors.yellow800);
    case 'pending_walker_acceptance':
      return _StatusConfig(
          'Awaiting Walker', AppColors.amber50, AppColors.amber500);
    case 'confirmed':
      return _StatusConfig('Confirmed', AppColors.green50, AppColors.green600);
    case 'walker_en_route':
      return _StatusConfig('En Route', AppColors.blue50, AppColors.blue600);
    case 'walk_started':
      return _StatusConfig(
          'Walk In Progress', AppColors.blue50, AppColors.blue700);
    case 'walk_completed':
      return _StatusConfig('Completed', AppColors.green50, AppColors.green700);
    case 'cancelled':
      return _StatusConfig('Cancelled', AppColors.red50, AppColors.red500);
    case 'disputed':
      return _StatusConfig(
          'Disputed', AppColors.purple50, AppColors.purple600);
    default:
      return _StatusConfig(
          status, AppColors.gray100, AppColors.textSecondary);
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onTap;

  const _BookingCard({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final walkerData = booking['walkers'] as Map<String, dynamic>?;
    final walkerUser = walkerData?['users'] as Map<String, dynamic>?;
    final dogData = booking['dogs'] as Map<String, dynamic>?;
    final walkerName = walkerUser?['full_name'] ?? 'Unknown Walker';
    final dogName = dogData?['name'] ?? 'Unknown Dog';
    final status = booking['status'] as String;
    final scheduledAt = booking['scheduled_at'] != null
        ? DateTime.tryParse(booking['scheduled_at'])
        : null;
    final duration = booking['duration_minutes'] as int?;
    final price = (booking['total_price_mxn'] as num?)?.toDouble();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Walker Info + Status
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.orange400, AppColors.orange500],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: walkerUser?['avatar_url'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            walkerUser!['avatar_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                walkerName.isNotEmpty
                                    ? walkerName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    fontSize: 24, color: Colors.white),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            walkerName.isNotEmpty
                                ? walkerName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 24, color: Colors.white),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        walkerName,
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _StatusBadge(status: status),
                    ],
                  ),
                ),
                Icon(PhosphorIcons.caretRight(),
                    color: AppColors.textTertiary, size: 24),
              ],
            ),
            const SizedBox(height: 16),
            // Dog name
            _DetailRow(
              icon: PhosphorIcons.pawPrint(),
              iconColor: AppColors.orange500,
              bgColor: AppColors.orange50,
              text: dogName,
            ),
            const SizedBox(height: 10),
            // Date
            if (scheduledAt != null) ...[
              _DetailRow(
                icon: PhosphorIcons.calendarBlank(),
                iconColor: AppColors.blue600,
                bgColor: AppColors.blue50,
                text: DateFormat('MMM d, yyyy').format(scheduledAt),
              ),
              const SizedBox(height: 10),
              _DetailRow(
                icon: PhosphorIcons.clock(),
                iconColor: AppColors.purple600,
                bgColor: AppColors.purple50,
                text:
                    '${DateFormat('h:mm a').format(scheduledAt)}${duration != null ? ' \u{00B7} $duration min' : ''}',
              ),
            ],
            // Price
            if (price != null) ...[
              const SizedBox(height: 10),
              _DetailRow(
                icon: PhosphorIcons.currencyDollar(),
                iconColor: AppColors.green600,
                bgColor: AppColors.green50,
                text: '\$${price.toStringAsFixed(2)} MXN',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Countdown banner shown in the booking detail sheet for pending_walker_acceptance.
class _CountdownBanner extends StatefulWidget {
  final String? acceptanceDeadline;
  const _CountdownBanner({required this.acceptanceDeadline});

  @override
  State<_CountdownBanner> createState() => _CountdownBannerState();
}

class _CountdownBannerState extends State<_CountdownBanner> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    if (widget.acceptanceDeadline == null) return;
    final deadline = DateTime.tryParse(widget.acceptanceDeadline!);
    if (deadline == null) return;

    _updateRemaining(deadline);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining(deadline);
    });
  }

  void _updateRemaining(DateTime deadline) {
    final now = DateTime.now().toUtc();
    final remaining = deadline.difference(now);
    if (!mounted) return;
    if (remaining.isNegative) {
      _timer?.cancel();
      setState(() {
        _expired = true;
        _remaining = Duration.zero;
      });
    } else {
      setState(() {
        _remaining = remaining;
        _expired = false;
      });
    }
  }

  String _formatCountdown(Duration d) {
    if (d.isNegative || d == Duration.zero) return '0:00';
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.acceptanceDeadline == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: _expired ? AppColors.red50 : AppColors.amber50,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        children: [
          Icon(
            _expired
                ? PhosphorIcons.warningCircle()
                : PhosphorIcons.hourglass(),
            size: 18,
            color: _expired ? AppColors.red500 : AppColors.amber500,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _expired
                  ? 'Request expired'
                  : 'Waiting for walker — ${_formatCountdown(_remaining)} remaining',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _expired ? AppColors.red500 : AppColors.yellow800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String text;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
