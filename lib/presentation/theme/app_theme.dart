import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

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
      cupertinoOverrideTheme: const NoDefaultCupertinoThemeData(
        primaryColor: HiveColors.honey,
        scaffoldBackgroundColor: HiveColors.background,
        textTheme: CupertinoTextThemeData(primaryColor: HiveColors.textPrimary),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: base.textTheme
          .copyWith(
            displayLarge: base.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -1.4,
            ),
            displayMedium: base.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -1.1,
            ),
            headlineLarge: base.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.9,
            ),
            headlineMedium: base.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
            titleLarge: base.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
            bodyLarge: base.textTheme.bodyLarge?.copyWith(
              fontSize: 17,
              height: 1.45,
            ),
            bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
            labelLarge: base.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          )
          .apply(
            bodyColor: HiveColors.textPrimary,
            displayColor: HiveColors.textPrimary,
          ),
      cardTheme: CardThemeData(
        color: HiveColors.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: HiveColors.outline),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: HiveColors.textPrimary,
        centerTitle: false,
        elevation: 0,
      ),
      dividerColor: HiveColors.outline,
      iconTheme: const IconThemeData(color: HiveColors.honey),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: HiveColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: base.textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HiveColors.honey,
          foregroundColor: HiveColors.background,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HiveColors.textPrimary,
          side: const BorderSide(color: HiveColors.outline),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
