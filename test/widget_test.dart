import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hive_flutter_v1/application/models/home_cell_preview.dart';
import 'package:hive_flutter_v1/application/models/home_dashboard_snapshot.dart';
import 'package:hive_flutter_v1/application/models/asset_mapping_explanation.dart';
import 'package:hive_flutter_v1/application/models/classification_outcome.dart';
import 'package:hive_flutter_v1/application/models/folder_detail_snapshot.dart';
import 'package:hive_flutter_v1/application/models/folder_detail_item.dart';
import 'package:hive_flutter_v1/application/models/hive_cell_category.dart';
import 'package:hive_flutter_v1/application/models/media_album.dart';
import 'package:hive_flutter_v1/application/models/scan_scope.dart';
import 'package:hive_flutter_v1/application/services/folder_detail_service.dart';
import 'package:hive_flutter_v1/application/services/home_dashboard_service.dart';
import 'package:hive_flutter_v1/application/services/manual_recategorization_service.dart';
import 'package:hive_flutter_v1/application/services/media_library_service.dart';
import 'package:hive_flutter_v1/application/services/permission_service.dart';
import 'package:hive_flutter_v1/application/services/scan_coordinator.dart';
import 'package:hive_flutter_v1/application/services/thumbnail_service.dart';
import 'package:hive_flutter_v1/domain/entities/classification_label.dart';
import 'package:hive_flutter_v1/domain/entities/media_asset.dart';
import 'package:hive_flutter_v1/domain/entities/scan_run.dart';
import 'package:hive_flutter_v1/domain/models/photo_permission_status.dart';
import 'package:hive_flutter_v1/main.dart';
import 'package:hive_flutter_v1/presentation/screens/folder_detail_screen.dart';
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
        home: HomeScreen(
          homeDashboardService: _FakeHomeDashboardService(),
          createFolderDetailService: _FakeFolderDetailService.new,
          createThumbnailService: _FakeThumbnailService.new,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pets'), findsOneWidget);

    await tester.ensureVisible(find.text('Pets'));
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();

    expect(find.text('Virtual cell details, member photos'), findsNothing);
    expect(find.text('Pets'), findsWidgets);
    expect(find.textContaining('Real scan-backed assets'), findsWidgets);
    expect(find.text('IMG_0001.HEIC'), findsOneWidget);

    await tester.tap(find.text('IMG_0001.HEIC'));
    await tester.pumpAndSettle();

    expect(find.text('Asset Detail'), findsOneWidget);
    expect(find.text('Move to Cell'), findsOneWidget);
    expect(find.text('Why This Landed Here'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Why This Landed Here'));
    await tester.pumpAndSettle();

    expect(find.text('Placement Detail'), findsOneWidget);
    expect(find.text('Mapped Category'), findsOneWidget);
    expect(find.text('Classification Status'), findsOneWidget);
    expect(find.text('dog'), findsWidgets);
  });

  testWidgets('HomeScreen can choose a smaller scan scope', (
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
          mediaLibraryService: _FakeMediaLibraryService(),
          createScanCoordinator: _FakeScanCoordinator.new,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Scan'));
    await tester.pumpAndSettle();

    expect(find.text('Choose Scan Scope'), findsOneWidget);
    expect(find.text('Summer Roll'), findsOneWidget);

    await tester.tap(find.text('Summer Roll'));
    await tester.pumpAndSettle();

    expect(find.text('Scan Progress'), findsOneWidget);
    expect(find.text('Scanning your library'), findsOneWidget);
    expect(find.text('Scope • Summer Roll'), findsOneWidget);
    expect(find.text('3 of 8'), findsOneWidget);
  });

  testWidgets('FolderDetailScreen can move an asset into another cell', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var currentCellId = 'pets';
    final folderDetailService = _MutableFolderDetailService(
      currentCellId: () => currentCellId,
    );
    final manualRecategorizationService = _FakeManualRecategorizationService(
      onMove: (_, targetCellId) {
        currentCellId = targetCellId;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: FolderDetailScreen(
          cellId: 'pets',
          cellName: 'Pets',
          folderDetailService: folderDetailService,
          manualRecategorizationService: manualRecategorizationService,
          thumbnailService: _FakeThumbnailService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('IMG_0001.HEIC'), findsOneWidget);

    await tester.tap(find.text('IMG_0001.HEIC'));
    await tester.pumpAndSettle();

    expect(find.text('Asset Detail'), findsOneWidget);
    expect(find.text('Move to Cell'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to Cell'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('People'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('Moved to People'), findsOneWidget);
    expect(find.text('Manual placement'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView).last, const Offset(0, 320));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();

    expect(find.text('No saved members yet'), findsOneWidget);
    expect(manualRecategorizationService.movedAssetId, 'asset_1');
    expect(manualRecategorizationService.targetCellId, 'people');
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
  Future<ScanRun> startFullScan({
    ScanScope scope = const ScanScope.allPhotos(),
  }) async {
    final discoveredAssetCount = scope.kind == ScanScopeKind.album ? 8 : 529;
    final classifiedAssetCount = scope.kind == ScanScopeKind.album ? 3 : 12;
    final run = ScanRun(
      id: 'scan_test',
      status: ScanRunStatus.running,
      startedAt: DateTime.now(),
      discoveredAssetCount: discoveredAssetCount,
      classifiedAssetCount: classifiedAssetCount,
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

class _FakeMediaLibraryService implements MediaLibraryService {
  @override
  Future<List<MediaAsset>> fetchAssets({
    DateTime? updatedAfter,
    int page = 0,
    int pageSize = 200,
    ScanScope scope = const ScanScope.allPhotos(),
  }) async {
    return const [];
  }

  @override
  Future<List<MediaAlbum>> getAvailableAlbums({int limit = 24}) async {
    return const [
      MediaAlbum(id: 'album_summer', name: 'Summer Roll', assetCount: 8),
    ];
  }

  @override
  Future<MediaAsset?> getAssetById(String assetId) async {
    return null;
  }

  @override
  Future<int> getEstimatedAssetCount({
    ScanScope scope = const ScanScope.allPhotos(),
  }) async {
    return scope.kind == ScanScopeKind.album ? 8 : 529;
  }
}

class _FakeFolderDetailService implements FolderDetailService {
  @override
  Future<FolderDetailSnapshot?> loadCell(String cellId) async {
    return _buildFolderDetailSnapshot(cellId: cellId, cellName: 'Pets');
  }
}

class _MutableFolderDetailService implements FolderDetailService {
  _MutableFolderDetailService({required this.currentCellId});

  final String Function() currentCellId;

  @override
  Future<FolderDetailSnapshot?> loadCell(String cellId) async {
    if (cellId != 'pets') {
      return null;
    }

    if (currentCellId() != 'pets') {
      return const FolderDetailSnapshot(
        cellId: 'pets',
        cellName: 'Pets',
        description: 'Real scan-backed assets grouped into this HIVE cell.',
        totalCount: 0,
        items: [],
      );
    }

    return _buildFolderDetailSnapshot(cellId: 'pets', cellName: 'Pets');
  }
}

class _FakeManualRecategorizationService
    implements ManualRecategorizationService {
  _FakeManualRecategorizationService({required this.onMove});

  final void Function(String assetId, String targetCellId) onMove;
  String? movedAssetId;
  String? targetCellId;

  @override
  List<HiveCellCategory> get availableTargetCells => hiveTopLevelCategories;

  @override
  Future<void> moveAssetToCell({
    required String assetId,
    required String targetCellId,
  }) async {
    movedAssetId = assetId;
    this.targetCellId = targetCellId;
    onMove(assetId, targetCellId);
  }
}

class _FakeThumbnailService implements ThumbnailService {
  @override
  Future<void> clearCache() async {}

  @override
  Future<Uint8List?> loadThumbnail({
    required MediaAsset asset,
    int size = 256,
  }) async {
    return null;
  }
}

FolderDetailSnapshot _buildFolderDetailSnapshot({
  required String cellId,
  required String cellName,
}) {
  final labels = [
    ClassificationLabel(
      id: 'dog',
      key: 'dog',
      displayName: 'dog',
      confidence: 0.91,
      source: ClassificationLabelSource.onDeviceModel,
      createdAt: DateTime(2026, 4, 18),
      modelIdentifier: 'test',
    ),
  ];

  return FolderDetailSnapshot(
    cellId: cellId,
    cellName: cellName,
    description: 'Real scan-backed assets grouped into this HIVE cell.',
    totalCount: 1,
    items: [
      FolderDetailItem(
        asset: MediaAsset(
          id: 'asset_1',
          type: MediaAssetType.image,
          createdAt: DateTime(2026, 4, 18),
          modifiedAt: DateTime(2026, 4, 18),
          width: 1200,
          height: 1600,
          originalFilename: 'IMG_0001.HEIC',
        ),
        title: 'IMG_0001.HEIC',
        subtitle: 'Photo • 2026-04-18',
        mappingExplanation: AssetMappingExplanation(
          cellId: cellId,
          cellName: cellName,
          score: 0.91,
          usedFallback: false,
          topLabels: labels,
          matchedKeywords: const ['dog', 'animal'],
        ),
        classificationOutcome: ClassificationOutcome(
          assetId: 'asset_1',
          status: ClassificationOutcomeStatus.succeeded,
          labels: labels,
          classificationRan: true,
          imagePreparationSucceeded: true,
          noLabelsReturned: false,
          modelIdentifier: 'test',
          sourceFormat: 'public.heic',
          preparedFormat: 'normalized_cgimage',
        ),
      ),
    ],
  );
}
