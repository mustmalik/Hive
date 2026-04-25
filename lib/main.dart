import 'package:flutter/material.dart';

import 'application/services/permission_service.dart';
import 'application/services/settings_service.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/theme/app_theme.dart';

void main() {
  runApp(const HiveApp());
}

class HiveApp extends StatelessWidget {
  const HiveApp({super.key, this.permissionService, this.settingsService});

  final PermissionService? permissionService;
  final SettingsService? settingsService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HIVE',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      home: SplashScreen(
        permissionService: permissionService,
        settingsService: settingsService,
      ),
    );
  }
}
