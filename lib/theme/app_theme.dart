import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary — WCAG AA compliant (3.16:1 vs white for large text)
  static const orange500 = Color(0xFFEA6C10);
  static const orange400 = Color(0xFFFB923C);
  static const orange50 = Color(0xFFFFF7ED);
  static const orange100 = Color(0xFFFFEDD5);

  // Background — warm cream base
  static const background = Color(0xFFFDF8F2);
  static const white = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF9F7F4);
  static const cardBackground = Color(0xFFFFFFFF);
  static const inputFill = Color(0xFFF9F7F4);

  // Text — WCAG AA compliant on background (#FDF8F2) and white
  static const textPrimary = Color(0xFF1A1A1A);   // 16.48:1 on background
  static const textSecondary = Color(0xFF6F6F6F);  // 4.76:1 on background
  static const textTertiary = Color(0xFF8A8A8A);   // 3.45:1 on white (decorative/non-essential)
  static const textLight = Color(0xFFAAAAAA);       // Placeholder/decorative only

  // Borders
  static const border = Color(0xFFF0ECE6);
  static const borderLight = Color(0xFFF0F0F0);
  static const borderDashed = Color(0xFFD8D0C8);
  static const divider = Color(0xFFE0E0E0);

  // Green
  static const green500 = Color(0xFF22C55E);
  static const green600 = Color(0xFF16A34A);
  static const green700 = Color(0xFF15803D);
  static const green50 = Color(0xFFF0FDF4);
  static const green100 = Color(0xFFDCFCE7);
  static const green200 = Color(0xFFBBF7D0);
  static const emerald400 = Color(0xFF34D399);

  // Blue
  static const blue500 = Color(0xFF3B82F6);
  static const blue600 = Color(0xFF2563EB);
  static const blue700 = Color(0xFF1D4ED8);
  static const blue50 = Color(0xFFEFF6FF);
  static const blue100 = Color(0xFFDBEAFE);
  static const blue400 = Color(0xFF60A5FA);

  // Purple
  static const purple500 = Color(0xFFA855F7);
  static const purple600 = Color(0xFF9333EA);
  static const purple50 = Color(0xFFFAF5FF);
  static const purple100 = Color(0xFFF3E8FF);
  static const purple400 = Color(0xFFC084FC);
  static const purple800 = Color(0xFF6B21A8);
  static const purple900 = Color(0xFF581C87);

  // Pink
  static const pink50 = Color(0xFFFDF2F8);
  static const pink400 = Color(0xFFF472B6);
  static const pink500 = Color(0xFFEC4899);

  // Red
  static const red500 = Color(0xFFEF4444);
  static const red50 = Color(0xFFFEF2F2);

  // Yellow / Amber
  static const yellow200 = Color(0xFFFDE68A);
  static const yellow400 = Color(0xFFFACC15);
  static const yellow800 = Color(0xFF854D0E);
  static const amber50 = Color(0xFFFFFBEB);
  static const amber500 = Color(0xFFF59E0B);
  static const green800 = Color(0xFF166534);

  // Gray
  static const gray100 = Color(0xFFF3F4F6);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray400 = Color(0xFF9CA3AF);

  // Dark mode palette
  static const darkBackground = Color(0xFF1A1A1E);
  static const darkSurface = Color(0xFF242428);
  static const darkCard = Color(0xFF2A2A2E);
  static const darkInputFill = Color(0xFF2E2E32);
  static const darkTextPrimary = Color(0xFFF0F0F0);
  static const darkTextSecondary = Color(0xFF9E9E9E);
  static const darkTextTertiary = Color(0xFF757575);
  static const darkBorder = Color(0xFF3A3A3E);
  static const darkBorderLight = Color(0xFF333336);
  static const darkDivider = Color(0xFF3A3A3E);
}

/// Design-system border radii for the minimalistic theme.
class AppRadius {
  static const double button = 12;
  static const double card = 16;
  static const double modal = 24;
  static const double bottomSheet = 24;
  static const double input = 12;
}

/// Design-system shadows — soft, no hard borders.
class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get cardPressed => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 14,
          offset: const Offset(0, 3),
        ),
      ];

  static List<BoxShadow> get elevated => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get subtle => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 1),
        ),
      ];
}

class AppTheme {
  static TextStyle get _baseTextStyle => GoogleFonts.nunito();

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.orange500,
          surface: AppColors.background,
        ),
        textTheme: TextTheme(
          headlineLarge: _baseTextStyle.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
          headlineMedium: _baseTextStyle.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
          headlineSmall: _baseTextStyle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
          titleLarge: _baseTextStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          titleMedium: _baseTextStyle.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
          bodyLarge: _baseTextStyle.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          bodyMedium: _baseTextStyle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
          bodySmall: _baseTextStyle.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
          labelLarge: _baseTextStyle.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          labelMedium: _baseTextStyle.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
          labelSmall: _baseTextStyle.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: _baseTextStyle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardBackground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.orange500,
            foregroundColor: AppColors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            textStyle: _baseTextStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.orange500,
            elevation: 0,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            side: const BorderSide(color: AppColors.orange500, width: 1.5),
            textStyle: _baseTextStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(
              color: AppColors.orange400,
              width: 1.5,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          hintStyle: _baseTextStyle.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: AppColors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.bottomSheet),
            ),
          ),
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.borderLight,
          thickness: 1,
          space: 1,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.white,
          elevation: 0,
          selectedItemColor: AppColors.orange500,
          unselectedItemColor: AppColors.textTertiary,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: PawgoPageTransitionsBuilder(),
            TargetPlatform.iOS: PawgoPageTransitionsBuilder(),
            TargetPlatform.macOS: PawgoPageTransitionsBuilder(),
            TargetPlatform.windows: PawgoPageTransitionsBuilder(),
            TargetPlatform.linux: PawgoPageTransitionsBuilder(),
          },
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.orange500,
          brightness: Brightness.dark,
          surface: AppColors.darkBackground,
        ),
        textTheme: TextTheme(
          headlineLarge: _baseTextStyle.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.darkTextPrimary,
            letterSpacing: -0.5,
          ),
          headlineMedium: _baseTextStyle.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.darkTextPrimary,
          ),
          headlineSmall: _baseTextStyle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.darkTextPrimary,
          ),
          titleLarge: _baseTextStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.darkTextPrimary,
          ),
          titleMedium: _baseTextStyle.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.darkTextSecondary,
          ),
          bodyLarge: _baseTextStyle.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.darkTextPrimary,
          ),
          bodyMedium: _baseTextStyle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.darkTextSecondary,
          ),
          bodySmall: _baseTextStyle.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.darkTextSecondary,
          ),
          labelLarge: _baseTextStyle.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.darkTextPrimary,
          ),
          labelMedium: _baseTextStyle.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.darkTextSecondary,
          ),
          labelSmall: _baseTextStyle.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.darkTextTertiary,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.darkSurface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: _baseTextStyle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.darkTextPrimary,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.orange500,
            foregroundColor: AppColors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            textStyle: _baseTextStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.orange400,
            elevation: 0,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            side: const BorderSide(color: AppColors.orange400, width: 1.5),
            textStyle: _baseTextStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkInputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(
              color: AppColors.orange400,
              width: 1.5,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          hintStyle: _baseTextStyle.copyWith(
            color: AppColors.darkTextTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: AppColors.darkSurface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.bottomSheet),
            ),
          ),
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.darkDivider,
          thickness: 1,
          space: 1,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkSurface,
          elevation: 0,
          selectedItemColor: AppColors.orange400,
          unselectedItemColor: AppColors.darkTextTertiary,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: PawgoPageTransitionsBuilder(),
            TargetPlatform.iOS: PawgoPageTransitionsBuilder(),
            TargetPlatform.macOS: PawgoPageTransitionsBuilder(),
            TargetPlatform.windows: PawgoPageTransitionsBuilder(),
            TargetPlatform.linux: PawgoPageTransitionsBuilder(),
          },
        ),
      );
}

/// Custom page transition: fadeIn + slideUp on push, fadeOut + slideDown on pop.
class PawgoPageTransitionsBuilder extends PageTransitionsBuilder {
  const PawgoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final reduceMotion = MediaQuery.of(context).accessibleNavigation;
    if (reduceMotion) return child;

    const curve = Cubic(0.25, 0.1, 0.25, 1.0); // smooth ease

    // Incoming page: fade + slide up
    final slideTween = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).chain(CurveTween(curve: curve));

    final fadeTween = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).chain(CurveTween(curve: curve));

    // Outgoing page: subtle fade out
    final secondaryFadeTween = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).chain(CurveTween(curve: curve));

    return FadeTransition(
      opacity: secondaryAnimation.drive(secondaryFadeTween),
      child: SlideTransition(
        position: animation.drive(slideTween),
        child: FadeTransition(
          opacity: animation.drive(fadeTween),
          child: child,
        ),
      ),
    );
  }
}

/// Custom route with slower duration for smooth transitions.
class PawgoPageRoute<T> extends MaterialPageRoute<T> {
  PawgoPageRoute({
    required super.builder,
    super.settings,
  });

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 450);
}
