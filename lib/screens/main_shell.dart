import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/widgets/top_bar.dart';
import 'package:pawgo/widgets/bottom_nav.dart';
import 'package:pawgo/widgets/walker_bottom_nav.dart';
import 'package:pawgo/screens/home_screen.dart';
import 'package:pawgo/screens/find_screen.dart';
import 'package:pawgo/screens/bookings_screen.dart';
import 'package:pawgo/screens/my_dogs_screen.dart';
import 'package:pawgo/screens/walker_bookings_screen.dart';
import 'package:pawgo/screens/walker_earnings_screen.dart';
import 'package:pawgo/screens/walker_chat_list_screen.dart';
import 'package:pawgo/screens/profile_screen.dart';
import 'package:pawgo/services/role_service.dart';
import 'package:pawgo/widgets/review_bottom_sheet.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _ownerIndex = 0;
  int _walkerIndex = 0;
  int _previousOwnerIndex = 0;
  int _previousWalkerIndex = 0;
  int _unreadChatCount = 0;

  final _roleService = RoleService.instance;
  final _supabase = Supabase.instance.client;
  Timer? _unreadPollTimer;
  RealtimeChannel? _walkCompletionChannel;
  RealtimeChannel? _reviewNotificationChannel;
  String? _walkerIdForReviewSub;
  RealtimeChannel? _newBookingChannel;
  Map<String, dynamic>? _pendingBookingNotification;

  final _ownerScreens = const [
    HomeScreen(),
    FindScreen(),
    BookingsScreen(),
    MyDogsScreen(),
  ];

  final _walkerScreens = const [
    WalkerBookingsScreen(),
    WalkerEarningsScreen(),
    WalkerChatListScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _roleService.activeRole.addListener(_onRoleChanged);
    _setupUnreadTracking();
    _subscribeToWalkCompletion();
    _setupReviewNotification();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        final tab = args['tab'] as int?;
        if (tab != null) {
          if (_isWalkerMode) {
            _onWalkerTabTap(tab);
          } else {
            _onOwnerTabTap(tab);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _roleService.activeRole.removeListener(_onRoleChanged);
    _unreadPollTimer?.cancel();
    _walkCompletionChannel?.unsubscribe();
    _reviewNotificationChannel?.unsubscribe();
    _newBookingChannel?.unsubscribe();
    super.dispose();
  }

  /// Subscribes to booking updates for the logged-in owner and shows the
  /// review sheet immediately when a walk transitions to walk_completed.
  /// This fires regardless of which tab the owner is currently on.
  void _subscribeToWalkCompletion() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _walkCompletionChannel = _supabase.channel('shell_walk_completion_$userId');
    _walkCompletionChannel!
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
            final status = payload.newRecord['status'] as String?;
            if (status == 'rejected_by_walker') {
              if (mounted) _showRejectionNotification();
              return;
            }
            if (status != 'walk_completed') return;
            // Give ActiveWalkScreen 300ms to handle it first (it has its own
            // subscription and shows the sheet immediately on the same event).
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              if (ReviewBottomSheet.shownThisSession) return;
              final bookingId = payload.newRecord['id'] as String?;
              final walkerId = payload.newRecord['walker_id'] as String?;
              if (bookingId == null || walkerId == null) return;
              _showWalkCompletedReview(bookingId, walkerId);
            });
          },
        )
        .subscribe();
  }

  Future<void> _showWalkCompletedReview(
      String bookingId, String walkerId) async {
    // Check if already reviewed (edge case: event fires twice)
    try {
      final existing = await _supabase
          .from('reviews')
          .select('id')
          .eq('booking_id', bookingId)
          .maybeSingle();
      if (existing != null) return;
    } catch (_) {
      return;
    }

    if (!mounted) return;
    if (ReviewBottomSheet.shownThisSession) return;

    // Fetch walker name for the sheet header
    String walkerName = 'your walker';
    try {
      final w = await _supabase
          .from('walkers')
          .select('users(full_name)')
          .eq('id', walkerId)
          .maybeSingle();
      walkerName =
          (w?['users'] as Map<String, dynamic>?)?['full_name'] as String? ??
              walkerName;
    } catch (_) {}

    if (!mounted) return;
    if (ReviewBottomSheet.shownThisSession) return;

    ReviewBottomSheet.shownThisSession = true;
    showModalBottomSheet<bool>(
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
    ).then((submitted) {
      if (submitted == true && mounted) {
        // Switch to the Bookings tab and show Past walks
        BookingsScreen.pendingInitialTab = 'past';
        _onOwnerTabTap(2);
      }
    });
  }

  /// US-012: Subscribe to Realtime INSERT on reviews table for this walker.
  /// When a new review arrives, show a SnackBar notification unless the
  /// walker is already viewing the Earnings tab (index 1).
  Future<void> _setupReviewNotification() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final walkerRes = await _supabase
          .from('walkers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (walkerRes == null) return;
      _walkerIdForReviewSub = walkerRes['id'] as String;
      _subscribeToReviewInserts(_walkerIdForReviewSub!);
      _subscribeToNewBookings(_walkerIdForReviewSub!);
    } catch (_) {
      // Non-critical — notification just won't fire
    }
  }

  void _subscribeToNewBookings(String walkerId) {
    _newBookingChannel?.unsubscribe();
    _newBookingChannel = _supabase.channel('walker_new_booking_$walkerId');
    _newBookingChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'walker_id',
            value: walkerId,
          ),
          callback: (payload) {
            if (!mounted) return;
            setState(() {
              _pendingBookingNotification = payload.newRecord;
            });
          },
        )
        .subscribe();
  }

  void _subscribeToReviewInserts(String walkerId) {
    _reviewNotificationChannel?.unsubscribe();
    _reviewNotificationChannel =
        _supabase.channel('walker_review_notify_$walkerId');
    _reviewNotificationChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reviews',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'walker_id',
            value: walkerId,
          ),
          callback: (payload) {
            if (!mounted) return;
            // Suppress if walker is on Earnings tab (index 1)
            if (_isWalkerMode && _walkerIndex == 1) return;
            _showReviewNotification();
          },
        )
        .subscribe();
  }

  void _showReviewNotification() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              PhosphorIcons.star(PhosphorIconsStyle.fill),
              color: AppColors.amber500,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'You received a new review!',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.cacaoBrown,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          textColor: AppColors.goldenPaw,
          onPressed: () {
            // Navigate to Earnings tab (walker index 1)
            if (_isWalkerMode) {
              _onWalkerTabTap(1);
            } else {
              // If in owner mode, switch to walker mode first then earnings
              _roleService.switchRole();
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) _onWalkerTabTap(1);
              });
            }
          },
        ),
      ),
    );
  }

  void _showRejectionNotification() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
              color: Colors.white70,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Your walk request was declined by the walker.',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.cacaoBrown,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Widget _buildNewBookingBanner() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: _pendingBookingNotification == null
          ? const SizedBox.shrink()
          : _NewBookingBanner(
              booking: _pendingBookingNotification!,
              onView: () {
                setState(() => _pendingBookingNotification = null);
                if (_isWalkerMode) {
                  _onWalkerTabTap(0);
                } else {
                  _roleService.switchRole();
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) _onWalkerTabTap(0);
                  });
                }
              },
              onDismiss: () =>
                  setState(() => _pendingBookingNotification = null),
            ),
    );
  }

  void _onRoleChanged() {
    if (mounted) setState(() {});
    _setupUnreadTracking();
  }

  bool get _isWalkerMode =>
      _roleService.activeRole.value == ActiveRole.walker;

  /// Sets up polling-based unread message tracking for walker mode.
  /// Uses lightweight REST polling instead of Realtime to avoid
  /// exhausting Postgres connection slots.
  void _setupUnreadTracking() {
    _unreadPollTimer?.cancel();

    if (!_isWalkerMode) {
      if (mounted) setState(() => _unreadChatCount = 0);
      return;
    }

    _fetchUnreadCount();

    // Poll every 60s — lightweight REST query, no Realtime channel needed
    _unreadPollTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        if (mounted) _fetchUnreadCount();
      },
    );
  }

  Future<void> _fetchUnreadCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Get walker profile ID
      final walkerRes = await _supabase
          .from('walkers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (walkerRes == null) return;
      final walkerId = walkerRes['id'] as String;

      // Get booking IDs for active chats
      final bookings = await _supabase
          .from('bookings')
          .select('id')
          .eq('walker_id', walkerId)
          .inFilter('status', ['confirmed', 'walk_started']);

      final bookingIds =
          (bookings as List).map((b) => b['id'] as String).toList();

      if (bookingIds.isEmpty) {
        if (mounted) setState(() => _unreadChatCount = 0);
        return;
      }

      // Count unread messages across all active bookings
      final unread = await _supabase
          .from('messages')
          .select('id')
          .inFilter('booking_id', bookingIds)
          .neq('sender_id', userId)
          .eq('is_read', false);

      if (mounted) {
        setState(() => _unreadChatCount = unread.length);
      }
    } catch (_) {
      // Non-critical — badge just won't update
    }
  }

  /// Switches to the given owner tab index. Callable from descendant widgets
  /// via `context.findAncestorStateOfType<MainShellState>()`.
  void switchOwnerTab(int index) => _onOwnerTabTap(index);

  void _onOwnerTabTap(int index) {
    if (index == _ownerIndex) return;
    setState(() {
      _previousOwnerIndex = _ownerIndex;
      _ownerIndex = index;
    });
  }

  void _onWalkerTabTap(int index) {
    if (index == _walkerIndex) return;
    setState(() {
      _previousWalkerIndex = _walkerIndex;
      _walkerIndex = index;
    });
    // Refresh unread count when switching to chat tab (messages get marked read)
    if (index == 2) {
      Future.delayed(const Duration(milliseconds: 500), _fetchUnreadCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).accessibleNavigation;
    final currentIndex = _isWalkerMode ? _walkerIndex : _ownerIndex;
    final previousIndex = _isWalkerMode ? _previousWalkerIndex : _previousOwnerIndex;
    final screens = _isWalkerMode ? _walkerScreens : _ownerScreens;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const TopBar(),
            _buildNewBookingBanner(),
            Expanded(
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (child, animation) {
                  if (reduceMotion) return child;

                  final isForward = currentIndex > previousIndex;
                  final slideOffset = Tween<Offset>(
                    begin: Offset(isForward ? 0.03 : -0.03, 0),
                    end: Offset.zero,
                  ).animate(animation);

                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: slideOffset,
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(currentIndex + (_isWalkerMode ? 100 : 0)),
                  child: screens[currentIndex],
                ),
              ),
            ),
            if (_isWalkerMode)
              WalkerBottomNav(
                currentIndex: _walkerIndex,
                onTap: _onWalkerTabTap,
                unreadChatCount: _unreadChatCount,
              )
            else
              BottomNav(
                currentIndex: _ownerIndex,
                onTap: _onOwnerTabTap,
              ),
          ],
        ),
      ),
    );
  }
}

class _NewBookingBanner extends StatelessWidget {
  const _NewBookingBanner({
    required this.booking,
    required this.onView,
    required this.onDismiss,
  });

  final Map<String, dynamic> booking;
  final VoidCallback onView;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheduledAt = booking['scheduled_at'] as String?;
    String timeLabel = '';
    if (scheduledAt != null) {
      try {
        final dt = DateTime.parse(scheduledAt).toLocal();
        timeLabel = DateFormat('EEE d MMM · h:mm a').format(dt);
      } catch (_) {}
    }

    return Container(
      key: const Key('new-booking-banner'),
      width: double.infinity,
      color: AppColors.goldenPaw,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIcons.pawPrint(PhosphorIconsStyle.fill),
            color: AppColors.cacaoBrown,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'New walk request!',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.cacaoBrown,
                  ),
                ),
                if (timeLabel.isNotEmpty)
                  Text(
                    timeLabel,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.cacaoBrown,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            key: const Key('new-booking-banner-view'),
            onPressed: onView,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.cacaoBrown,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'View',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            key: const Key('new-booking-banner-dismiss'),
            onPressed: onDismiss,
            icon: Icon(
              PhosphorIcons.x(),
              color: AppColors.cacaoBrown,
              size: 18,
            ),
            padding: const EdgeInsets.all(AppSpacing.sm),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
