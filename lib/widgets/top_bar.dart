import 'package:flutter/material.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/services/role_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ActiveRole>(
      valueListenable: RoleService.instance.activeRole,
      builder: (context, activeRole, _) {
        final isWalkerMode = activeRole == ActiveRole.walker;
        final accentColor =
            isWalkerMode ? AppColors.cacaoBrown : AppColors.orange500;
        final title = isWalkerMode ? 'Pawgo Walker' : 'Pawgo';

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Icon(
                        isWalkerMode ? PhosphorIcons.personSimpleWalk() : PhosphorIcons.pawPrint(),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isWalkerMode
                        ? AppColors.cacaoBrown.withValues(alpha: 0.12)
                        : AppColors.orange100,
                    border: Border.all(color: accentColor, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      'd',
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
