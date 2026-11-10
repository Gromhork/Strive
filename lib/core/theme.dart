import 'package:flutter/material.dart';

/// Central design tokens for Strive.
class AppColors {
  static const brand = Color(0xFF8B7CFF); // violet – neutral to all sports
  static const brandDark = Color(0xFF6A5AE0);

  static const gym = Color(0xFFFF6B3D); // coral
  static const run = Color(0xFF2FD38A); // green
  static const ride = Color(0xFFFFB627); // amber
  static const swim = Color(0xFF3DB2FF); // blue

  static const success = Color(0xFF2FD38A);
  static const warning = Color(0xFFFFB627);
  static const danger = Color(0xFFFF4D6D);

  // Dark surfaces
  static const bgDark = Color(0xFF0D1117);
  static const surfaceDark = Color(0xFF151B23);
  static const cardDark = Color(0xFF1B232D);
  static const outlineDark = Color(0xFF2A3441);

  // Light surfaces
  static const bgLight = Color(0xFFF4F5FA);
  static const cardLight = Colors.white;
}

class AppTheme {
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: b,
      primary: AppColors.brand,
      surface: dark ? AppColors.surfaceDark : AppColors.bgLight,
      surfaceContainer: dark ? AppColors.cardDark : AppColors.cardLight,
      surfaceContainerHigh: dark ? const Color(0xFF222C38) : const Color(0xFFECEDF4),
      surfaceContainerHighest: dark ? const Color(0xFF2A3542) : const Color(0xFFE2E4EE),
      outlineVariant: dark ? AppColors.outlineDark : const Color(0xFFDADCE6),
      error: AppColors.danger,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: dark ? AppColors.bgDark : AppColors.bgLight,
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? AppColors.bgDark : AppColors.bgLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: dark ? 0.6 : 0.4)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? AppColors.surfaceDark : Colors.white,
        indicatorColor: AppColors.brand.withValues(alpha: 0.22),
        surfaceTintColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? AppColors.surfaceDark : Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(backgroundColor: dark ? AppColors.surfaceDark : Colors.white, surfaceTintColor: Colors.transparent),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), space: 1),
      // Floating, rounded, app-coloured snack bars (the M3 default is a full-width light bar).
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF2A3542) : const Color(0xFF1B232D),
        contentTextStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Colors.white),
        actionTextColor: dark ? AppColors.brand : const Color(0xFFB4AAFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        elevation: 4,
        // Keep "Rückgängig" on the same line (M3 moves actions wider than 25 % below).
        actionOverflowThreshold: 0.45,
      ),
    );
  }
}
