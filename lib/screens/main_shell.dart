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
    super.dispose();
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

    // Poll every 15s — lightweight REST query, no Realtime channel needed
    _unreadPollTimer = Timer.periodic(
      const Duration(seconds: 15),
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
