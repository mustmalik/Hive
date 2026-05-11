import 'dart:async';

import 'package:flutter/material.dart';

import 'application/models/classification_backend.dart';
import 'application/services/permission_service.dart';
import 'application/services/settings_service.dart';
import 'data/services/google_mlkit_classification_service.dart';
import 'data/services/structural_signal_extractor.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/theme/app_theme.dart';

const _classificationBackendEnvKey = 'HIVE_CLASSIFICATION_BACKEND';

void main() {
  final classificationBackend = ClassificationBackend.parse(
    const String.fromEnvironment(_classificationBackendEnvKey),
  );

  runApp(HiveApp(classificationBackend: classificationBackend));
}

class HiveApp extends StatefulWidget {
  const HiveApp({
    super.key,
    this.permissionService,
    this.settingsService,
    this.classificationBackend = ClassificationBackend.appleVision,
  });

  final PermissionService? permissionService;
  final SettingsService? settingsService;
  final ClassificationBackend classificationBackend;

  @override
  State<HiveApp> createState() => _HiveAppState();
}

class _HiveAppState extends State<HiveApp> {
  @override
  void dispose() {
    unawaited(GoogleMlKitClassificationService.disposeSharedResources());
    unawaited(StructuralSignalExtractor.disposeSharedDetectors());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HIVE',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      home: SplashScreen(
        permissionService: widget.permissionService,
        settingsService: widget.settingsService,
        classificationBackend: widget.classificationBackend,
      ),
    );
  }
}
