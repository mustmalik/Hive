import 'package:flutter/material.dart';

import 'application/services/permission_service.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/theme/app_theme.dart';

void main() {
  runApp(const HiveApp());
}

class HiveApp extends StatelessWidget {
  const HiveApp({super.key, this.permissionService});

  final PermissionService? permissionService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HIVE',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      home: SplashScreen(permissionService: permissionService),
    );
  }
}
