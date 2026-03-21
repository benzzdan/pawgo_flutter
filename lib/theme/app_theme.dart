import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary
  static const orange500 = Color(0xFFF97316);
  static const orange400 = Color(0xFFFB923C);
  static const orange50 = Color(0xFFFFF7ED);
  static const orange100 = Color(0xFFFFEDD5);

  // Background
  static const background = Color(0xFFFDF8F2);
  static const white = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF5F5F5);

  // Text
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF888888);
  static const textTertiary = Color(0xFFAAAAAA);
  static const textLight = Color(0xFFBBBBBB);

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
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
          headlineMedium: _baseTextStyle.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
          headlineSmall: _baseTextStyle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
          titleLarge: _baseTextStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
          titleMedium: _baseTextStyle.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
          bodyLarge: _baseTextStyle.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          bodyMedium: _baseTextStyle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
          bodySmall: _baseTextStyle.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
          labelLarge: _baseTextStyle.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          labelMedium: _baseTextStyle.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
          labelSmall: _baseTextStyle.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.white,
          elevation: 0,
          titleTextStyle: _baseTextStyle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
      );
}
