import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hive_flutter_v1/application/models/home_cell_preview.dart';
import 'package:hive_flutter_v1/application/models/home_dashboard_snapshot.dart';
import 'package:hive_flutter_v1/application/services/home_dashboard_service.dart';
import 'package:hive_flutter_v1/application/services/permission_service.dart';
import 'package:hive_flutter_v1/application/services/scan_coordinator.dart';
import 'package:hive_flutter_v1/domain/entities/scan_run.dart';
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
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: HomeScreen(homeDashboardService: _FakeHomeDashboardService()),
      ),
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

  testWidgets('HomeScreen start scan opens scan progress', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: HomeScreen(
          homeDashboardService: _FakeHomeDashboardService(),
          createScanCoordinator: _FakeScanCoordinator.new,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Scan'));
    await tester.pumpAndSettle();

    expect(find.text('Scan Progress'), findsOneWidget);
    expect(find.text('Scanning your library'), findsOneWidget);
    expect(find.text('12 of 529'), findsOneWidget);
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

class _FakeHomeDashboardService implements HomeDashboardService {
  @override
  Future<HomeDashboardSnapshot> loadDashboard() async {
    return HomeDashboardSnapshot(
      totalAssetCount: 529,
      totalCellCount: 12,
      lastCompletedScanAt: DateTime.now().subtract(const Duration(hours: 2)),
      visibleCells: const [
        HomeCellPreview(
          id: 'pets',
          name: 'Pets',
          assetCount: 128,
          summary: 'Warm moments and familiar faces',
          styleKey: 'pets',
          featured: true,
        ),
        HomeCellPreview(
          id: 'travel',
          name: 'Travel',
          assetCount: 84,
          summary: 'Trips, weekends, and new places',
          styleKey: 'travel',
        ),
      ],
    );
  }
}

class _FakeScanCoordinator implements ScanCoordinator {
  final StreamController<ScanRun> _controller =
      StreamController<ScanRun>.broadcast();

  @override
  Future<void> cancelActiveRun() async {}

  @override
  Future<ScanRun?> getLatestRun() async {
    return null;
  }

  @override
  Future<ScanRun> startFullScan() async {
    final run = ScanRun(
      id: 'scan_test',
      status: ScanRunStatus.running,
      startedAt: DateTime.now(),
      discoveredAssetCount: 529,
      classifiedAssetCount: 12,
      generatedCellCount: 1,
      currentStageLabel: 'Grouping moments into cells',
      currentItemTitle: 'IMG_1042.JPG',
      latestDetectedCellName: 'Pets',
    );

    _controller.add(run);
    return run;
  }

  @override
  Stream<ScanRun> watchActiveRun() => _controller.stream;
}
