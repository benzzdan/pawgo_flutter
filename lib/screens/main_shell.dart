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

  @override
  Widget build(BuildContext context) {
    final currentIndex = _isWalkerMode ? _walkerIndex : _ownerIndex;
    final screens = _isWalkerMode ? _walkerScreens : _ownerScreens;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const TopBar(),
            Expanded(child: screens[currentIndex]),
            if (_isWalkerMode)
              WalkerBottomNav(
                currentIndex: _walkerIndex,
                onTap: (index) => setState(() => _walkerIndex = index),
              )
            else
              BottomNav(
                currentIndex: _ownerIndex,
                onTap: (index) => setState(() => _ownerIndex = index),
              ),
          ],
        ),
      ),
    );
  }
}
