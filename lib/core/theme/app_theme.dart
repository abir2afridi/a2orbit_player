import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../providers/app_providers.dart';

class AppTheme {
  static ThemeData light(AppThemeData data) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: data.accentColor,
      brightness: Brightness.light,
    );
    return _baseTheme(colorScheme, data);
  }

  static ThemeData dark(AppThemeData data) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: data.accentColor,
      brightness: Brightness.dark,
    );
    return _baseTheme(colorScheme, data);
  }

  static ThemeData amoled(AppThemeData data) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: data.accentColor,
      brightness: Brightness.dark,
    );
    final amoledScheme = baseScheme.copyWith(
      background: AppColors.amoledBackground,
      surface: AppColors.amoledSurface,
      surfaceVariant: AppColors.amoledSurface,
    );
    return _baseTheme(amoledScheme, data);
  }

  static ThemeData _baseTheme(ColorScheme colorScheme, AppThemeData data) {
    var finalColorScheme = colorScheme;
    var finalScaffoldColor = colorScheme.background;
    var finalAppBarTheme = _appBarTheme(colorScheme, data);

    if (data.style == ThemeStyle.ahs && data.ahsColor != null) {
      final ahsColor = data.ahsColor!;
      final isLight = ahsColor.computeLuminance() > 0.5;
      final contentColor = isLight ? Colors.black : Colors.white;

      finalScaffoldColor = ahsColor;
      finalColorScheme = colorScheme.copyWith(
        background: ahsColor,
        surface: ahsColor,
        surfaceVariant: ahsColor.withOpacity(0.8),
        onBackground: contentColor,
        onSurface: contentColor,
        onSurfaceVariant: contentColor.withOpacity(0.7),
      );
      finalAppBarTheme = finalAppBarTheme.copyWith(
        backgroundColor: ahsColor,
        foregroundColor: contentColor,
      );
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: finalColorScheme,
      scaffoldBackgroundColor: finalScaffoldColor,
      appBarTheme: finalAppBarTheme,
      bottomNavigationBarTheme: _bottomNavigationTheme(finalColorScheme),
      cardTheme: _cardTheme(finalColorScheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: finalColorScheme.primary,
          foregroundColor: finalColorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      iconTheme: IconThemeData(color: finalColorScheme.onSurface),
      textTheme: _textTheme(finalColorScheme),
      sliderTheme: SliderThemeData(
        activeTrackColor: finalColorScheme.primary,
        inactiveTrackColor: finalColorScheme.primary.withOpacity(0.25),
        thumbColor: finalColorScheme.primary,
        overlayColor: finalColorScheme.primary.withOpacity(0.12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return finalColorScheme.primary;
          }
          return finalColorScheme.onSurfaceVariant;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return finalColorScheme.primaryContainer;
          }
          return finalColorScheme.onSurface.withOpacity(0.15);
        }),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: finalColorScheme.primary,
        textColor: finalColorScheme.onSurface,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: finalColorScheme.primary.withOpacity(0.12),
        selectedColor: finalColorScheme.primary.withOpacity(0.2),
        labelStyle: TextStyle(color: finalColorScheme.onSurface),
        secondaryLabelStyle: TextStyle(color: finalColorScheme.onSurface),
      ),
    );
  }

  static AppBarTheme _appBarTheme(ColorScheme colorScheme, AppThemeData data) {
    Color? backgroundColor = colorScheme.surface;
    Color? foregroundColor = colorScheme.onSurface;

    if (data.style == ThemeStyle.dynamic && data.headerColor != null) {
      backgroundColor = data.headerColor;
      // Calculate contrast color for content
      if (backgroundColor!.computeLuminance() > 0.5) {
        foregroundColor = Colors.black;
      } else {
        foregroundColor = Colors.white;
      }
    } else if (data.style == ThemeStyle.ahs && data.ahsColor != null) {
      backgroundColor = data.ahsColor;
      if (backgroundColor!.computeLuminance() > 0.5) {
        foregroundColor = Colors.black;
      } else {
        foregroundColor = Colors.white;
      }
    }

    return AppBarTheme(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: foregroundColor,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: foregroundColor),
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
