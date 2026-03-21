import 'package:flutter/material.dart';
import 'package:pawgo/widgets/top_bar.dart';
import 'package:pawgo/widgets/bottom_nav.dart';
import 'package:pawgo/screens/home_screen.dart';
import 'package:pawgo/screens/find_screen.dart';
import 'package:pawgo/screens/bookings_screen.dart';
import 'package:pawgo/screens/my_dogs_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = [
    const HomeScreen(),
    const FindScreen(),
    const BookingsScreen(),
    const MyDogsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const TopBar(),
            Expanded(child: _screens[_currentIndex]),
            BottomNav(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
            ),
          ],
        ),
      ),
    );
  }
}
