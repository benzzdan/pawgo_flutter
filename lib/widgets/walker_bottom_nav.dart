import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class WalkerBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int unreadChatCount;

  const WalkerBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadChatCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(PhosphorIcons.calendarBlank(), PhosphorIcons.calendarBlank(PhosphorIconsStyle.fill), 'My Walks'),
      _NavItem(PhosphorIcons.wallet(), PhosphorIcons.wallet(PhosphorIconsStyle.fill), 'Earnings'),
      _NavItem(PhosphorIcons.chatCircle(), PhosphorIcons.chatCircle(PhosphorIconsStyle.fill), 'Chat'),
      _NavItem(PhosphorIcons.user(), PhosphorIcons.user(PhosphorIconsStyle.fill), 'Profile'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isActive = currentIndex == index;
              final showBadge = index == 2 && unreadChatCount > 0;
              return GestureDetector(
                onTap: () => onTap(index),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 64,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            isActive ? item.activeIcon : item.icon,
                            size: 26,
                            color: isActive
                                ? AppColors.cacaoBrown
                                : AppColors.textLight,
                          ),
                          if (showBadge)
                            Positioned(
                              top: -6,
                              right: -10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.red500,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AppColors.white, width: 1.5),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Center(
                                  child: Text(
                                    unreadChatCount > 99
                                        ? '99+'
                                        : '$unreadChatCount',
                                    style: GoogleFonts.nunito(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? AppColors.cacaoBrown
                              : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}
