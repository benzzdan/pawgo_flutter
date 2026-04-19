import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawgo/services/analytics_service.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:pawgo/services/gps_broadcast_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';

class WalkerBookingsScreen extends StatefulWidget {
  const WalkerBookingsScreen({super.key, this.initialTab = 0});
  final int initialTab;
  static const int defaultInitialTab = 0;

  /// Set to true before navigating to this screen to auto-switch to the
  /// Upcoming tab and scroll to the Pending Requests section.
  /// The screen reads and clears this flag in initState.
  static bool pendingScrollToRequests = false;

  @override
  State<WalkerBookingsScreen> createState() => _WalkerBookingsScreenState();
}

class _WalkerBookingsScreenState extends State<WalkerBookingsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;
  String? _error;
  String? _walkerId;
  RealtimeChannel? _bookingChannel;
  int _selectedTab = 0; // 0=Upcoming, 1=Active, 2=Completed
  String? _startingWalkId; // Booking ID currently being started (loading state)
  final ScrollController _scrollController = ScrollController();

  static const _upcomingStatuses = ['confirmed', 'walker_en_route'];
  static const _activeStatuses = ['walk_started'];
  static const _completedStatuses = ['walk_completed'];

  /// Bookings awaiting this walker's accept/decline response.
  List<Map<String, dynamic>> get _pendingBookings =>
      _bookings.where((b) => b['status'] == 'pending_walker_acceptance').toList();

  List<Map<String, dynamic>> get _filteredBookings {
    final statuses = switch (_selectedTab) {
      0 => _upcomingStatuses,
      1 => _activeStatuses,
      2 => _completedStatuses,
      _ => _upcomingStatuses,
    };
    return _bookings
        .where((b) => statuses.contains(b['status']))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    // Consume the pendingScrollToRequests flag — if set, force Upcoming tab
    // and scroll to top after data loads so pending requests are visible.
    final shouldScroll = WalkerBookingsScreen.pendingScrollToRequests;
    if (shouldScroll) {
      WalkerBookingsScreen.pendingScrollToRequests = false;
      _selectedTab = 0; // Upcoming tab shows pending requests
    } else {
      _selectedTab = widget.initialTab;
    }
    _loadWalkerBookings().then((_) {
      if (shouldScroll) _scrollToTop();
    });
  }

  @override
  void dispose() {
    _bookingChannel?.unsubscribe();
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls the list to the top so the Pending Requests section is visible.
  void _scrollToTop() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Shows a snackbar alerting the walker to a new walk request.
  /// Tapping 'View' switches to the Upcoming tab and scrolls to the
  /// Pending Requests section at the top of the list.
  void _showNewRequestSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'New walk request received!',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.cacaoBrown,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'View',
          textColor: AppColors.goldenPaw,
          onPressed: () {
            setState(() => _selectedTab = 0);
            _scrollToTop();
          },
        ),
      ),
    );
  }

  Future<void> _loadWalkerBookings() async {
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

      // Get walker profile for current user
      final walkerRes = await withRetry(() => _supabase
          .from('walkers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle());

      if (walkerRes == null) {
        setState(() {
          _isLoading = false;
          _error = 'No walker profile found. You need a walker account to view this screen.';
        });
        return;
      }

      _walkerId = walkerRes['id'] as String;

      // Fetch all bookings assigned to this walker (including pending acceptance)
      final bookings = await withRetry(() => _supabase
          .from('bookings')
          .select('*, dogs(name, breed, photo_url), users!bookings_owner_id_fkey(full_name, avatar_url), walkers(user_id, hourly_rate_mxn)')
          .eq('walker_id', _walkerId!)
          .inFilter('status', ['pending_walker_acceptance', 'confirmed', 'walker_en_route', 'walk_started', 'walk_completed'])
          .order('scheduled_at', ascending: true));

      setState(() {
        _bookings = List<Map<String, dynamic>>.from(bookings);
        _isLoading = false;
      });

      _subscribeToBookings();
    } catch (e) {
      if (!mounted) return;
      final appError = AppError.from(e);
      if (appError.isAuthError) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }
      setState(() {
        _isLoading = false;
        _error = appError.isNetworkError
            ? 'No internet connection. Please check your network.'
            : 'Failed to load bookings';
      });
    }
  }

  void _subscribeToBookings() {
    if (_walkerId == null) return;
    _bookingChannel?.unsubscribe();

    _bookingChannel = _supabase
        .channel('walker-bookings-$_walkerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'walker_id',
            value: _walkerId!,
          ),
          callback: (payload) {
            // New booking assigned — reload to get joined data
            _loadWalkerBookings().then((_) {
              if (!mounted) return;
              final status = payload.newRecord['status'] as String?;
              if (status == 'pending_walker_acceptance') {
                _showNewRequestSnackbar();
              }
            });
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'walker_id',
            value: _walkerId!,
          ),
          callback: (payload) {
            final updated = payload.newRecord;
            setState(() {
              final idx = _bookings.indexWhere((b) => b['id'] == updated['id']);
              if (idx >= 0) {
                final status = updated['status'] as String?;
                // Remove cancelled bookings
                if (status == 'cancelled') {
                  _bookings.removeAt(idx);
                } else {
                  // Preserve joined data, update booking fields
                  _bookings[idx] = {
                    ..._bookings[idx],
                    ...updated,
                    'dogs': _bookings[idx]['dogs'],
                    'users': _bookings[idx]['users'],
                    'walkers': _bookings[idx]['walkers'],
                  };
                }
              }
            });
          },
        )
        .subscribe();
  }

  Future<void> _startWalk(String bookingId) async {
    setState(() => _startingWalkId = bookingId);
    try {
      final res = await withRetry(() => _supabase.functions.invoke(
        'start-walk',
        body: {'booking_id': bookingId},
      ));

      if (!mounted) return;
      if (res.status != 200) {
        setState(() => _startingWalkId = null);
        ErrorHandler.instance.handleFunctionError(
          context,
          res,
          screen: 'walker_bookings',
          fallbackMessage: 'Failed to start walk',
        );
      } else {
        AnalyticsService.instance.walkStarted(bookingId: bookingId);

        // Start GPS broadcasting
        await GpsBroadcastService.instance.startBroadcasting(bookingId);

        if (!mounted) return;
        setState(() => _startingWalkId = null);

        // Get walker and dog names for route args
        final booking = _bookings.firstWhere(
          (b) => b['id'] == bookingId,
          orElse: () => <String, dynamic>{},
        );
        final currentUser = _supabase.auth.currentUser;
        final walkerName = currentUser?.userMetadata?['full_name'] as String?
            ?? booking['users']?['full_name'] as String?
            ?? 'Walker';
        final dogName = booking['dogs']?['name'] as String? ?? 'Dog';

        // Navigate to active walk screen
        Navigator.pushNamed(context, '/active-walk', arguments: {
          'booking_id': bookingId,
          'walker_name': walkerName,
          'dog_name': dogName,
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _startingWalkId = null);
      ErrorHandler.instance.handleError(
        context,
        e,
        screen: 'walker_bookings',
        fallbackMessage: 'Failed to start walk. Please try again.',
      );
    }
  }

  Future<void> _endWalk(String bookingId) async {
    // Confirm before ending
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('End Walk?', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to end this walk?', style: GoogleFonts.nunito()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange500),
            child: Text('End Walk', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await withRetry(() => _supabase.functions.invoke(
        'end-walk',
        body: {'booking_id': bookingId},
      ));

      if (!mounted) return;
      if (res.status != 200) {
        ErrorHandler.instance.handleFunctionError(
          context,
          res,
          screen: 'walker_bookings',
          fallbackMessage: 'Failed to end walk',
        );
      } else {
        AnalyticsService.instance.walkCompleted(bookingId: bookingId);
        ErrorHandler.instance.showRecoverableError(context, 'Walk completed!');
      }
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.instance.handleError(
        context,
        e,
        screen: 'walker_bookings',
        fallbackMessage: 'Failed to end walk. Please try again.',
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppColors.blue600;
      case 'walker_en_route':
        return AppColors.orange500;
      case 'walk_started':
        return AppColors.green600;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppColors.blue50;
      case 'walker_en_route':
        return AppColors.orange50;
      case 'walk_started':
        return AppColors.green50;
      default:
        return AppColors.surface;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmed';
      case 'walker_en_route':
        return 'En Route';
      case 'walk_started':
        return 'In Progress';
      default:
        return status;
    }
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'Not scheduled';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    final local = dt.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final amPm = local.hour >= 12 ? 'PM' : 'AM';
    final min = local.minute.toString().padLeft(2, '0');
    return '${months[local.month - 1]} ${local.day}, ${local.year} at $hour:$min $amPm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'My Walk Sessions',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: PawProgressIndicator(color: AppColors.orange500))
          : _error != null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildFilterTabs(),
                    Expanded(child: _buildTabContent()),
                  ],
                ),
    );
  }

  Widget _buildFilterTabs() {
    final tabs = ['Upcoming', 'Active', 'Completed'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.cacaoBrown : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    tabs[index],
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    final pending = _selectedTab == 0 ? _pendingBookings : <Map<String, dynamic>>[];
    final filtered = _filteredBookings;
    final hasPending = pending.isNotEmpty;
    final hasFiltered = filtered.isNotEmpty;
    final isEmpty = !hasPending && !hasFiltered;

    return RefreshIndicator(
      onRefresh: _loadWalkerBookings,
      color: AppColors.orange500,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (isEmpty)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: _buildEmptyState(),
            )
          else ...[
            if (hasPending) ...[
              _buildPendingRequestsSection(pending),
              if (hasFiltered) const SizedBox(height: AppSpacing.lg),
            ],
            ...filtered.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _buildBookingCard(b),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingRequestsSection(List<Map<String, dynamic>> pending) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.amber500,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Pending Requests',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.amber500.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${pending.length}',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.amber500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...pending.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _buildPendingCard(b),
            )),
      ],
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> booking) {
    final dog = booking['dogs'] as Map<String, dynamic>?;
    final owner = booking['users'] as Map<String, dynamic>?;
    final bookingId = booking['id'] as String;
    final scheduledAt = booking['scheduled_at'] as String?;
    final durationMinutes = booking['duration_minutes'];
    final deadlineStr = booking['acceptance_deadline'] as String?;

    // Compute time remaining for the mini countdown
    String? deadlineLabel;
    if (deadlineStr != null) {
      final deadline = DateTime.tryParse(deadlineStr);
      if (deadline != null) {
        final remaining = deadline.difference(DateTime.now().toUtc());
        if (remaining.isNegative) {
          deadlineLabel = 'Expired';
        } else {
          final mins = remaining.inMinutes;
          final secs = remaining.inSeconds % 60;
          deadlineLabel = '${mins}m ${secs.toString().padLeft(2, '0')}s left';
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
        border: Border.all(
          color: AppColors.amber500.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.orange50,
                child: Icon(PhosphorIcons.user(),
                    size: 20, color: AppColors.orange500),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      owner?['full_name'] ?? 'Dog Owner',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${dog?['name'] ?? 'Dog'} · ${durationMinutes ?? '?'} min',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (deadlineLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: deadlineLabel == 'Expired'
                        ? AppColors.red50
                        : AppColors.amber50,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Text(
                    deadlineLabel,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: deadlineLabel == 'Expired'
                          ? AppColors.red500
                          : AppColors.yellow800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(PhosphorIcons.calendarBlank(),
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _formatDateTime(scheduledAt),
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/walk-request', arguments: {
                  'booking_id': bookingId,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber500,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
              child: Text(
                'View Request',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.warningCircle(), size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadWalkerBookings,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange500),
              child: Text('Retry', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.personSimpleWalk(), size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              _selectedTab == 2 ? 'No Completed Walks' : 'No Walks Assigned Yet',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedTab == 0
                  ? 'You don\'t have any upcoming walks right now.'
                  : _selectedTab == 1
                      ? 'No walks are currently in progress.'
                      : 'You haven\'t completed any walks yet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 15, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] as String? ?? 'confirmed';
    final dog = booking['dogs'] as Map<String, dynamic>?;
    final owner = booking['users'] as Map<String, dynamic>?;
    final bookingId = booking['id'] as String;
    final scheduledAt = booking['scheduled_at'] as String?;
    final durationMinutes = booking['duration_minutes'];
    final totalPrice = booking['total_price_mxn'];
    final notes = booking['notes'] as String?;
    final dogPhotoUrl = dog?['photo_url'] as String?;

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Owner and status row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.orange50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: owner?['avatar_url'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          owner!['avatar_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(PhosphorIcons.user(), color: AppColors.orange500),
                        ),
                      )
                    : Icon(PhosphorIcons.user(), color: AppColors.orange500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      owner?['full_name'] ?? 'Dog Owner',
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusBgColor(status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(status),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Dog info with photo
          if (dog != null) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.orange50,
                  backgroundImage: dogPhotoUrl != null ? NetworkImage(dogPhotoUrl) : null,
                  onBackgroundImageError: dogPhotoUrl != null
                      ? (_, __) {}
                      : null,
                  child: dogPhotoUrl == null
                      ? Icon(PhosphorIcons.pawPrint(), size: 20, color: AppColors.orange500)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${dog['name'] ?? 'Unknown'} (${dog['breed'] ?? 'Unknown breed'})',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          // Scheduled time
          _DetailRow(
            icon: PhosphorIcons.calendarBlank(),
            iconColor: AppColors.blue600,
            bgColor: AppColors.blue50,
            text: _formatDateTime(scheduledAt),
          ),
          // Booking notes
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Text(
                notes,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          // Duration & price
          if (durationMinutes != null || totalPrice != null) ...[
            const SizedBox(height: 10),
            _DetailRow(
              icon: PhosphorIcons.clock(),
              iconColor: AppColors.purple600,
              bgColor: AppColors.purple50,
              text: [
                if (durationMinutes != null) '${durationMinutes} min',
                if (totalPrice != null) '\$${(totalPrice as num).toStringAsFixed(0)} MXN',
              ].join(' · '),
            ),
          ],
          const SizedBox(height: 16),
          // Action buttons
          _buildActionButtons(bookingId, status, scheduledAt),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String bookingId, String status, String? scheduledAt) {
    final isStarting = _startingWalkId == bookingId;

    if (status == 'confirmed' || status == 'walker_en_route') {
      // Only allow starting within 5 minutes of scheduled time
      final scheduledTime = scheduledAt != null ? DateTime.tryParse(scheduledAt) : null;
      final now = DateTime.now().toUtc();
      final canStart = scheduledTime == null ||
          now.isAfter(scheduledTime.subtract(const Duration(minutes: 5)));

      final minutesUntilStart = scheduledTime != null
          ? scheduledTime.subtract(const Duration(minutes: 5)).difference(now).inMinutes
          : 0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: isStarting || !canStart ? null : () => _startWalk(bookingId),
                    icon: isStarting
                        ? const PawProgressIndicator(size: 18, strokeWidth: 2, color: Colors.white)
                        : Icon(PhosphorIcons.play(PhosphorIconsStyle.fill),
                            color: canStart ? Colors.white : Colors.white54),
                    label: Text(
                      isStarting
                          ? 'Starting...'
                          : canStart
                              ? 'Start Walk'
                              : 'Starts in ${minutesUntilStart}m',
                      style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canStart ? AppColors.green600 : AppColors.gray400,
                      disabledBackgroundColor: canStart
                          ? AppColors.green600.withValues(alpha: 0.7)
                          : AppColors.gray400,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: canStart ? 2 : 0,
                    ),
                  ),
                ),
              ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            width: 48,
            child: IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/chat', arguments: {
                  'booking_id': bookingId,
                  'other_party_name': _bookings.firstWhere((b) => b['id'] == bookingId)['users']?['full_name'] ?? 'Owner',
                });
              },
              icon: Icon(PhosphorIcons.chatCircle(), color: AppColors.orange500),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.orange50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      if (!canStart)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIcons.clock(), size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(
                'Available to start 5 min before scheduled time',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
      );
    } else if (status == 'walk_started') {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _endWalk(bookingId),
                icon: Icon(PhosphorIcons.stop(PhosphorIconsStyle.fill), color: Colors.white),
                label: Text(
                  'End Walk',
                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            width: 48,
            child: IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/active-walk', arguments: {
                  'booking_id': bookingId,
                });
              },
              icon: Icon(PhosphorIcons.mapTrifold(), color: AppColors.blue600),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.blue50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            width: 48,
            child: IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/chat', arguments: {
                  'booking_id': bookingId,
                  'other_party_name': _bookings.firstWhere((b) => b['id'] == bookingId)['users']?['full_name'] ?? 'Owner',
                });
              },
              icon: Icon(PhosphorIcons.chatCircle(), color: AppColors.orange500),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.orange50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
    } else {
      // walk_completed or other states — no action buttons
      return const SizedBox.shrink();
    }
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
