import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryBlue = Color(0xFF0D7BCE);
  static const Color accentLavender = Color(0xFF6A70F5);
  static const Color softLilac = Color(0xFFF3F4FF);
  static const Color surfaceTint = Color(0xFFF8FAFF);
  static const Color neutralText = Color(0xFF1E1F25);

  static const List<Color> backgroundGradient = [
    Color(0xFFF4F8FF),
    Color(0xFFE1F1FF),
    Color(0xFFC8E7FF),
    primaryBlue,
  ];

  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x1A014F8E),
    blurRadius: 30,
    spreadRadius: 0,
    offset: Offset(0, 18),
  );

  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, fontFamily: 'Segoe UI');
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.light,
          primary: primaryBlue,
          secondary: accentLavender,
          surface: surfaceTint,
        ).copyWith(
          onSurface: neutralText,
          onSurfaceVariant: const Color(0xFF4A4D57),
          surfaceTint: primaryBlue,
          tertiary: const Color(0xFF6F7BF7),
          onTertiary: Colors.white,
          outline: const Color(0x33748AA1),
          outlineVariant: const Color(0x19748AA1),
        );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF1E1F25),
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: neutralText,
        displayColor: neutralText,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.82),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        shadowColor: cardShadow.color,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w600),
        ),
        indicatorColor: Colors.white,
        backgroundColor: Colors.white,
        elevation: 4,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          side: const BorderSide(color: Color(0x332B83CA)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: neutralText,
        ),
      ),
    );
  }
}
