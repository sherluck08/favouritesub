import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'brand.dart';

class AppTheme {
  static const _brand = Color(0xFF490000);
  static const _darkBrand = Color(0xFFFFB4B4);

  static ThemeData light() {
    final scheme = Brand.colorScheme(brightness: Brightness.light).copyWith(
      primary: _brand,
      onPrimary: Colors.white,
      surface: const Color(0xFFFFFBFF),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFAF5F5),
      surfaceContainer: const Color(0xFFF5EFEF),
      surfaceContainerHigh: const Color(0xFFEFE8E8),
      outlineVariant: const Color(0xFFE0D7D7),
    );
    return _baseTheme(
      scheme,
    ).copyWith(scaffoldBackgroundColor: const Color(0xFFF8F5F5));
  }

  static ThemeData dark() {
    final scheme = Brand.colorScheme(brightness: Brightness.dark).copyWith(
      primary: _darkBrand,
      onPrimary: const Color(0xFF3B0002),
      secondary: const Color(0xFFE7BDBD),
      surface: const Color(0xFF151112),
      onSurface: const Color(0xFFF1E8E8),
      onSurfaceVariant: const Color(0xFFD2C2C2),
      surfaceContainerLowest: const Color(0xFF0F0C0D),
      surfaceContainerLow: const Color(0xFF1C1718),
      surfaceContainer: const Color(0xFF211B1C),
      surfaceContainerHigh: const Color(0xFF2A2324),
      surfaceContainerHighest: const Color(0xFF352D2E),
      outline: const Color(0xFF9D8C8D),
      outlineVariant: const Color(0xFF514647),
      error: const Color(0xFFFFB4AB),
    );
    return _baseTheme(scheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFF100D0E),
      canvasColor: const Color(0xFF151112),
    );
  }

  static ThemeData _baseTheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final primaryIsDark =
        ThemeData.estimateBrightnessForColor(scheme.primary) == Brightness.dark;
    final baseText = isDark
        ? ThemeData.dark(useMaterial3: true).textTheme
        : ThemeData.light(useMaterial3: true).textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      textTheme: GoogleFonts.montserratTextTheme(
        baseText,
      ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: scheme.onPrimary),
        actionsIconTheme: IconThemeData(color: scheme.onPrimary),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: scheme.primary,
          statusBarIconBrightness: primaryIsDark
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: primaryIsDark
              ? Brightness.dark
              : Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        modalBackgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.1),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? scheme.surfaceContainerHighest
            : const Color(0xFF282122),
        contentTextStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}
