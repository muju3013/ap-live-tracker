import 'package:flutter/material.dart';

abstract class AppColors {
  static const Color primaryRed = Color(0xFFD71920);
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primaryText = Color(0xFF101828);
  static const Color secondaryText = Color(0xFF667085);
  static const Color successLive = Color(0xFF12B76A);
  static const Color warning = Color(0xFFF79009);
  static const Color info = Color(0xFF2970FF);
  static const Color border = Color(0xFFEAECF0);
  static const Color cardShadow = Color(0x0C101828);
}

abstract class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double horizontalPadding = 20.0;
}

abstract class AppRadius {
  static const double card = 20.0;
  static const double button = 16.0;
  static const double chip = 12.0;
  static const double input = 14.0;
  static const double sheet = 24.0;
}

abstract class AppSizes {
  static const double minTouchTarget = 48.0;
  static const double buttonHeight = 52.0;
}

abstract class AppTypography {
  static const TextStyle headerTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
    letterSpacing: -0.5,
  );

  static const TextStyle headerSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.secondaryText,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: AppColors.secondaryText,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 0.2,
  );

  static const TextStyle badgeLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );
}

ThemeData buildAppTheme({bool isDark = false}) {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primaryRed,
    primary: AppColors.primaryRed,
    surface: isDark ? const Color(0xFF1D2939) : AppColors.surface,
    brightness: isDark ? Brightness.dark : Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: baseScheme,
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF101828)
        : AppColors.background,
    cardTheme: CardThemeData(
      color: isDark ? const Color(0xFF1D2939) : AppColors.surface,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? const Color(0xFF1D2939) : AppColors.surface,
      foregroundColor: isDark ? Colors.white : AppColors.primaryText,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppColors.primaryText,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        minimumSize: const Size(AppSizes.minTouchTarget, AppSizes.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        textStyle: AppTypography.buttonLabel,
      ),
    ),
  );
}
