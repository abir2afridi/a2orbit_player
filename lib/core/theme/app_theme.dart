import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../providers/app_providers.dart';

class AppTheme {
  static ThemeData light(AppThemeData data) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: data.accentColor,
      brightness: Brightness.light,
    );
    return _baseTheme(colorScheme);
  }

  static ThemeData dark(AppThemeData data) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: data.accentColor,
      brightness: Brightness.dark,
    );
    return _baseTheme(colorScheme);
  }

  static ThemeData amoled(AppThemeData data) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: data.accentColor,
      brightness: Brightness.dark,
    );
    final amoledScheme = baseScheme.copyWith(
      background: AppColors.amoledBackground,
      surface: AppColors.amoledSurface,
    );
    return _baseTheme(amoledScheme).copyWith(
      scaffoldBackgroundColor: AppColors.amoledBackground,
      colorScheme: amoledScheme,
      appBarTheme: _appBarTheme(amoledScheme),
      bottomNavigationBarTheme: _bottomNavigationTheme(amoledScheme),
      cardTheme: _cardTheme(amoledScheme),
    );
  }

  static ThemeData _baseTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      appBarTheme: _appBarTheme(colorScheme),
      bottomNavigationBarTheme: _bottomNavigationTheme(colorScheme),
      cardTheme: _cardTheme(colorScheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      textTheme: _textTheme(colorScheme),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.primary.withOpacity(0.25),
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withOpacity(0.12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.onSurfaceVariant;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primaryContainer;
          }
          return colorScheme.onSurface.withOpacity(0.15);
        }),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        textColor: colorScheme.onSurface,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.primary.withOpacity(0.12),
        selectedColor: colorScheme.primary.withOpacity(0.2),
        labelStyle: TextStyle(color: colorScheme.onSurface),
        secondaryLabelStyle: TextStyle(color: colorScheme.onSurface),
      ),
    );
  }

  static AppBarTheme _appBarTheme(ColorScheme colorScheme) {
    return AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    );
  }

  static BottomNavigationBarThemeData _bottomNavigationTheme(
    ColorScheme colorScheme,
  ) {
    return BottomNavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
      type: BottomNavigationBarType.fixed,
      elevation: colorScheme.brightness == Brightness.light ? 8 : 4,
    );
  }

  static CardThemeData _cardTheme(ColorScheme colorScheme) {
    return CardThemeData(
      color: colorScheme.surface,
      elevation: colorScheme.brightness == Brightness.light ? 2 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  static TextTheme _textTheme(ColorScheme colorScheme) {
    final baseColor = colorScheme.onBackground;
    return TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: baseColor,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: baseColor.withOpacity(0.9)),
      bodyMedium: TextStyle(fontSize: 14, color: baseColor.withOpacity(0.85)),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
    );
  }
}
