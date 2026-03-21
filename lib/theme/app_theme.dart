import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Spacing tokens used throughout the app for consistent layout.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppColors {
  // Brand Primary
  static const cacaoBrown = Color(0xFF4A2C2A);
  static const warmCaramel = Color(0xFFC07D4D);
  static const goldenPaw = Color(0xFFF4A832);

  // Legacy primary aliases (used by existing screens)
  static const orange500 = Color(0xFFF97316);
  static const orange400 = Color(0xFFFB923C);
  static const orange50 = Color(0xFFFFF7ED);
  static const orange100 = Color(0xFFFFEDD5);

  // Background
  static const background = Color(0xFFFDF8F2);
  static const white = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF5F5F5);

  // Dark mode backgrounds
  static const darkBackground = Color(0xFF1A1A1A);
  static const darkSurface = Color(0xFF2A2A2A);
  static const darkCard = Color(0xFF333333);

  // Text
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF888888);
  static const textTertiary = Color(0xFFAAAAAA);
  static const textLight = Color(0xFFBBBBBB);

  // Dark mode text
  static const darkTextPrimary = Color(0xFFF5F5F5);
  static const darkTextSecondary = Color(0xFFAAAAAA);
  static const darkTextTertiary = Color(0xFF888888);

  // Borders
  static const border = Color(0xFFF0ECE6);
  static const borderLight = Color(0xFFF0F0F0);
  static const borderDashed = Color(0xFFD8D0C8);
  static const divider = Color(0xFFE0E0E0);

  // Dark mode borders
  static const darkBorder = Color(0xFF444444);
  static const darkDivider = Color(0xFF3A3A3A);

  // Green
  static const green500 = Color(0xFF22C55E);
  static const green600 = Color(0xFF16A34A);
  static const green700 = Color(0xFF15803D);
  static const green50 = Color(0xFFF0FDF4);
  static const green100 = Color(0xFFDCFCE7);
  static const green200 = Color(0xFFBBF7D0);
  static const emerald400 = Color(0xFF34D399);
  static const green800 = Color(0xFF166534);

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

  // Gray
  static const gray100 = Color(0xFFF3F4F6);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray400 = Color(0xFF9CA3AF);
}

class AppTheme {
  static TextStyle get _baseTextStyle => GoogleFonts.nunito();

  static TextTheme _buildTextTheme({
    required Color primary,
    required Color secondary,
    required Color tertiary,
  }) {
    return TextTheme(
      headlineLarge: _baseTextStyle.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: primary,
        letterSpacing: -0.5,
      ),
      headlineMedium: _baseTextStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: primary,
      ),
      headlineSmall: _baseTextStyle.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleLarge: _baseTextStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleMedium: _baseTextStyle.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
      bodyLarge: _baseTextStyle.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyMedium: _baseTextStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      bodySmall: _baseTextStyle.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      labelLarge: _baseTextStyle.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      labelMedium: _baseTextStyle.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: secondary,
      ),
      labelSmall: _baseTextStyle.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: tertiary,
      ),
    );
  }

  /// Light theme — default.
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.light(
          primary: AppColors.cacaoBrown,
          secondary: AppColors.warmCaramel,
          tertiary: AppColors.goldenPaw,
          surface: AppColors.background,
          error: AppColors.red500,
          onPrimary: AppColors.white,
          onSecondary: AppColors.white,
          onSurface: AppColors.textPrimary,
          onError: AppColors.white,
        ),
        textTheme: _buildTextTheme(
          primary: AppColors.textPrimary,
          secondary: AppColors.textSecondary,
          tertiary: AppColors.textTertiary,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.white,
          elevation: 0,
          titleTextStyle: _baseTextStyle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(48, 48),
            textStyle: _baseTextStyle.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
        ),
      );

  /// Dark theme.
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBackground,
        colorScheme: ColorScheme.dark(
          primary: AppColors.warmCaramel,
          secondary: AppColors.goldenPaw,
          tertiary: AppColors.cacaoBrown,
          surface: AppColors.darkSurface,
          error: AppColors.red500,
          onPrimary: AppColors.white,
          onSecondary: AppColors.darkBackground,
          onSurface: AppColors.darkTextPrimary,
          onError: AppColors.white,
        ),
        textTheme: _buildTextTheme(
          primary: AppColors.darkTextPrimary,
          secondary: AppColors.darkTextSecondary,
          tertiary: AppColors.darkTextTertiary,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.darkSurface,
          elevation: 0,
          titleTextStyle: _baseTextStyle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.darkTextPrimary,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(48, 48),
            textStyle: _baseTextStyle.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
        ),
        cardTheme: const CardThemeData(
          color: AppColors.darkCard,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.darkDivider,
        ),
      );
}
