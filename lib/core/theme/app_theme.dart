import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightPrimary,
        primaryContainer: AppColors.lightPrimaryVariant,
        secondary: AppColors.lightSecondary,
        secondaryContainer: AppColors.lightSecondaryVariant,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        error: AppColors.lightError,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
        onBackground: AppColors.black,
        onSurface: AppColors.black,
        onError: AppColors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.black,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.black,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: AppColors.lightPrimary,
        unselectedItemColor: AppColors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.lightSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightPrimary,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.black, size: 24),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.black,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.black,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.black),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.black),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.black,
        ),
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkPrimary,
        primaryContainer: AppColors.darkPrimaryVariant,
        secondary: AppColors.darkSecondary,
        secondaryContainer: AppColors.darkSecondaryVariant,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        error: AppColors.darkError,
        onPrimary: AppColors.black,
        onSecondary: AppColors.black,
        onBackground: AppColors.white,
        onSurface: AppColors.white,
        onError: AppColors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.darkPrimary,
        unselectedItemColor: AppColors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.darkSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: AppColors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.white, size: 24),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.white),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.white),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.white,
        ),
      ),
    );
  }

  // AMOLED Theme
  static ThemeData get amoledTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkPrimary,
        primaryContainer: AppColors.darkPrimaryVariant,
        secondary: AppColors.darkSecondary,
        secondaryContainer: AppColors.darkSecondaryVariant,
        background: AppColors.amoledBackground,
        surface: AppColors.amoledSurface,
        error: AppColors.darkError,
        onPrimary: AppColors.black,
        onSecondary: AppColors.black,
        onBackground: AppColors.white,
        onSurface: AppColors.white,
        onError: AppColors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.amoledBackground,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.amoledBackground,
        selectedItemColor: AppColors.darkPrimary,
        unselectedItemColor: AppColors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.amoledSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.white, size: 24),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.white),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.white),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.white,
        ),
      ),
    );
  }
}
