import 'package:flutter/material.dart';
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
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _ownerIndex = 0;
  int _walkerIndex = 0;
  int _previousOwnerIndex = 0;
  int _previousWalkerIndex = 0;

  final _roleService = RoleService.instance;

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
  }

  @override
  void dispose() {
    _roleService.activeRole.removeListener(_onRoleChanged);
    super.dispose();
  }

  void _onRoleChanged() {
    if (mounted) setState(() {});
  }

  bool get _isWalkerMode =>
      _roleService.activeRole.value == ActiveRole.walker;

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
