import 'package:flutter/material.dart';

import 'hive_colors.dart';

abstract final class AppTheme {
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: HiveColors.honey,
      onPrimary: HiveColors.background,
      secondary: HiveColors.amberGlow,
      onSecondary: HiveColors.background,
      surface: HiveColors.surface,
      onSurface: HiveColors.textPrimary,
      error: Color(0xFFFF8A80),
      onError: Colors.black,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: HiveColors.background,
      canvasColor: HiveColors.background,
      textTheme: base.textTheme.apply(
        bodyColor: HiveColors.textPrimary,
        displayColor: HiveColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: HiveColors.textPrimary,
        centerTitle: false,
        elevation: 0,
      ),
      dividerColor: HiveColors.outline,
      iconTheme: const IconThemeData(color: HiveColors.honey),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HiveColors.honey,
          foregroundColor: HiveColors.background,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HiveColors.textPrimary,
          side: const BorderSide(color: HiveColors.outline),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
