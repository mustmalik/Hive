import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hive_flutter_v1/application/services/permission_service.dart';
import 'package:hive_flutter_v1/domain/models/photo_permission_status.dart';
import 'package:hive_flutter_v1/main.dart';
import 'package:hive_flutter_v1/presentation/screens/home_screen.dart';
import 'package:hive_flutter_v1/presentation/theme/app_theme.dart';

void main() {
  testWidgets('HIVE flows from splash to onboarding to permission', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const HiveApp(permissionService: _FakePermissionService()),
    );

    expect(find.text('HIVE'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Introduction'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacy & Access'));
    await tester.pumpAndSettle();

    expect(find.text('Privacy & Access'), findsOneWidget);
    expect(find.text('Let HIVE organize locally.'), findsOneWidget);
    expect(find.text('Allow Photo Access'), findsOneWidget);
  });

  testWidgets('HomeScreen cell tap opens folder detail', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: const HomeScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pets'), findsOneWidget);

    await tester.ensureVisible(find.text('Pets'));
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();

    expect(find.text('Virtual cell details, member photos'), findsNothing);
    expect(find.text('Pets'), findsWidgets);
    expect(find.textContaining('Pets is a virtual HIVE cell.'), findsOneWidget);
  });
}

class _FakePermissionService implements PermissionService {
  const _FakePermissionService();

  @override
  Future<PhotoPermissionStatus> getPhotoPermissionStatus() async {
    return PhotoPermissionStatus.notRequested;
  }

  @override
  Future<void> openPhotoSettings() async {}

  @override
  Future<PhotoPermissionStatus> presentLimitedPhotoPicker() async {
    return PhotoPermissionStatus.limited;
  }

  @override
  Future<PhotoPermissionStatus> requestPhotoPermission() async {
    return PhotoPermissionStatus.fullAccess;
  }
}
