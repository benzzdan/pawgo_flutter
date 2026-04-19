import 'dart:async';
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
import 'package:pawgo/utils/booking_notification_helpers.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

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
            final newStatus = payload.newRecord['status'] as String?;
            if (newStatus == null) return;

            // US-009: Owner notification when walker accepts (confirmed)
            if (shouldShowOwnerConfirmation(newStatus, true)) {
              _showWalkConfirmedSnackbar();
            }

            if (newStatus != 'walk_completed') return;
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

  /// Shows a floating snackbar when a walker accepts the owner's booking.
  /// Styled to match the walker's new-request snackbar (US-003).
  void _showWalkConfirmedSnackbar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Your walk has been confirmed!',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.cacaoBrown,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          textColor: AppColors.goldenPaw,
          onPressed: () {
            BookingsScreen.pendingInitialTab = 'upcoming';
            _onOwnerTabTap(2);
          },
        ),
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
