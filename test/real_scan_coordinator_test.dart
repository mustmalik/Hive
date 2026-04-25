import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter_v1/application/models/asset_mapping_explanation.dart';
import 'package:hive_flutter_v1/data/repositories/in_memory_classification_repository.dart';
import 'package:hive_flutter_v1/data/repositories/in_memory_manual_override_repository.dart';
import 'package:hive_flutter_v1/application/models/classification_outcome.dart';
import 'package:hive_flutter_v1/application/models/media_album.dart';
import 'package:hive_flutter_v1/application/models/scan_scope.dart';
import 'package:hive_flutter_v1/data/repositories/in_memory_folder_cell_repository.dart';
import 'package:hive_flutter_v1/data/repositories/in_memory_media_asset_repository.dart';
import 'package:hive_flutter_v1/application/services/classification_service.dart';
import 'package:hive_flutter_v1/application/services/folder_mapping_service.dart';
import 'package:hive_flutter_v1/application/services/media_library_service.dart';
import 'package:hive_flutter_v1/data/repositories/in_memory_scan_run_repository.dart';
import 'package:hive_flutter_v1/data/services/keyword_folder_mapping_service.dart';
import 'package:hive_flutter_v1/data/services/real_scan_coordinator.dart';
import 'package:hive_flutter_v1/domain/entities/classification_label.dart';
import 'package:hive_flutter_v1/domain/entities/folder_cell.dart';
import 'package:hive_flutter_v1/domain/entities/manual_override.dart';
import 'package:hive_flutter_v1/domain/entities/media_asset.dart';
import 'package:hive_flutter_v1/domain/entities/scan_run.dart';

void main() {
  test(
    'RealScanCoordinator emits real batched progress and completes',
    () async {
      final manualOverrideRepository = InMemoryManualOverrideRepository();
      final folderCellRepository = InMemoryFolderCellRepository(
        seedCells: const [],
      );
      final coordinator = RealScanCoordinator(
        mediaLibraryService: _FakeMediaLibraryService(),
        classificationService: _FakeClassificationService(),
        folderMappingService: KeywordFolderMappingService(
          now: () => DateTime(2026, 4, 18),
        ),
        classificationRepository: InMemoryClassificationRepository(),
        manualOverrideRepository: manualOverrideRepository,
        mediaAssetRepository: InMemoryMediaAssetRepository(
          seedAssets: const [],
        ),
        folderCellRepository: folderCellRepository,
        scanRunRepository: InMemoryScanRunRepository(seedRuns: const []),
        pageSize: 2,
        now: () => DateTime(2026, 4, 18, 12),
      );

      final events = <ScanRun>[];
      final completed = Completer<ScanRun>();
      final subscription = coordinator.watchActiveRun().listen((run) {
        events.add(run);
        if (run.isTerminal && !completed.isCompleted) {
          completed.complete(run);
        }
      });

      addTearDown(subscription.cancel);

      final queued = await coordinator.startFullScan();
      expect(queued.status, ScanRunStatus.queued);

      final completedRun = await completed.future.timeout(
        const Duration(seconds: 3),
      );

      final videosCell = await folderCellRepository.getCellById('videos');

      expect(completedRun.status, ScanRunStatus.completed);
      expect(completedRun.discoveredAssetCount, 3);
      expect(completedRun.classifiedAssetCount, 3);
      expect(completedRun.generatedCellCount, 3);
      expect(completedRun.latestDetectedCellName, 'Food');
      expect(completedRun.currentStageLabel, 'Cells ready');

      final runningEvents = events.where(
        (run) => run.status == ScanRunStatus.running,
      );
      expect(runningEvents.length, greaterThanOrEqualTo(3));
      expect(
        runningEvents.map((run) => run.classifiedAssetCount),
        containsAllInOrder([1, 2, 3]),
      );
      expect(
        runningEvents.any(
          (run) =>
              run.currentItemTitle == 'IMG_0001.HEIC' &&
              run.latestDetectedCellName == 'Pets',
        ),
        isTrue,
      );
      expect(videosCell, isNotNull);
      expect(videosCell!.assetIds, contains('asset_2'));
    },
  );

  test('RealScanCoordinator honors manual overrides on later scans', () async {
    final folderCellRepository = InMemoryFolderCellRepository(
      seedCells: const [],
    );
    final manualOverrideRepository = InMemoryManualOverrideRepository(
      seedOverrides: [
        ManualOverride(
          id: 'manual_asset_1_people',
          assetId: 'asset_1',
          action: ManualOverrideAction.includeInCell,
          createdAt: DateTime(2026, 4, 18, 9),
          cellId: 'people',
          note: 'manual_move',
        ),
      ],
    );
    final coordinator = RealScanCoordinator(
      mediaLibraryService: _FakeMediaLibraryService(),
      classificationService: _FakeClassificationService(),
      folderMappingService: KeywordFolderMappingService(
        now: () => DateTime(2026, 4, 18),
      ),
      classificationRepository: InMemoryClassificationRepository(),
      manualOverrideRepository: manualOverrideRepository,
      mediaAssetRepository: InMemoryMediaAssetRepository(seedAssets: const []),
      folderCellRepository: folderCellRepository,
      scanRunRepository: InMemoryScanRunRepository(seedRuns: const []),
      pageSize: 3,
      now: () => DateTime(2026, 4, 18, 12),
    );

    final completed = Completer<ScanRun>();
    final subscription = coordinator.watchActiveRun().listen((run) {
      if (run.isTerminal && !completed.isCompleted) {
        completed.complete(run);
      }
    });
    addTearDown(subscription.cancel);

    await coordinator.startFullScan();
    final run = await completed.future.timeout(const Duration(seconds: 3));

    final peopleCell = await folderCellRepository.getCellById('people');
    final petsCell = await folderCellRepository.getCellById('pets');

    expect(run.status, ScanRunStatus.completed);
    expect(peopleCell, isNotNull);
    expect(peopleCell!.assetIds, contains('asset_1'));
    expect(petsCell?.assetIds.contains('asset_1') ?? false, isFalse);
  });

  test(
    'RealScanCoordinator reuses cached classifications for unchanged assets',
    () async {
      final asset = _FakeMediaLibraryService._assets.first;
      final cachedOutcome = ClassificationOutcome(
        assetId: asset.id,
        status: ClassificationOutcomeStatus.succeeded,
        labels: [
          ClassificationLabel(
            id: 'cached_dog',
            key: 'cached_dog',
            displayName: 'dog',
            confidence: 0.93,
            source: ClassificationLabelSource.onDeviceModel,
            createdAt: DateTime(2026, 4, 18, 9),
            modelIdentifier: 'cached',
          ),
        ],
        classificationRan: true,
        imagePreparationSucceeded: true,
        noLabelsReturned: false,
        modelIdentifier: 'cached',
      );
      final classificationRepository = InMemoryClassificationRepository(
        seedOutcomes: {asset.id: cachedOutcome},
      );
      final classificationService = _CountingClassificationService(
        labelsByAssetId: {
          asset.id: [
            ClassificationLabel(
              id: 'fresh_dog',
              key: 'fresh_dog',
              displayName: 'dog',
              confidence: 0.91,
              source: ClassificationLabelSource.onDeviceModel,
              createdAt: DateTime(2026, 4, 18, 12),
              modelIdentifier: 'fresh',
            ),
          ],
        },
      );
      final coordinator = RealScanCoordinator(
        mediaLibraryService: _ConfigurableMediaLibraryService([asset]),
        classificationService: classificationService,
        folderMappingService: KeywordFolderMappingService(
          now: () => DateTime(2026, 4, 18),
        ),
        classificationRepository: classificationRepository,
        manualOverrideRepository: InMemoryManualOverrideRepository(),
        mediaAssetRepository: InMemoryMediaAssetRepository(seedAssets: [asset]),
        folderCellRepository: InMemoryFolderCellRepository(seedCells: const []),
        scanRunRepository: InMemoryScanRunRepository(seedRuns: const []),
        pageSize: 1,
        now: () => DateTime(2026, 4, 18, 12),
      );

      final completed = Completer<ScanRun>();
      final subscription = coordinator.watchActiveRun().listen((run) {
        if (run.isTerminal && !completed.isCompleted) {
          completed.complete(run);
        }
      });
      addTearDown(subscription.cancel);

      await coordinator.startFullScan();
      final run = await completed.future.timeout(const Duration(seconds: 3));
      final stored = await classificationRepository.getOutcomesForAssetIds([
        asset.id,
      ]);

      expect(run.status, ScanRunStatus.completed);
      expect(classificationService.callCount, 0);
      expect(stored[asset.id]?.modelIdentifier, 'cached');
    },
  );

  test(
    'RealScanCoordinator only builds suggested cells once per scan',
    () async {
      final folderMappingService = _CountingFolderMappingService(
        KeywordFolderMappingService(now: () => DateTime(2026, 4, 18)),
      );
      final coordinator = RealScanCoordinator(
        mediaLibraryService: _FakeMediaLibraryService(),
        classificationService: _FakeClassificationService(),
        folderMappingService: folderMappingService,
        classificationRepository: InMemoryClassificationRepository(),
        manualOverrideRepository: InMemoryManualOverrideRepository(),
        mediaAssetRepository: InMemoryMediaAssetRepository(
          seedAssets: const [],
        ),
        folderCellRepository: InMemoryFolderCellRepository(seedCells: const []),
        scanRunRepository: InMemoryScanRunRepository(seedRuns: const []),
        pageSize: 2,
        now: () => DateTime(2026, 4, 18, 12),
      );

      final completed = Completer<ScanRun>();
      final subscription = coordinator.watchActiveRun().listen((run) {
        if (run.isTerminal && !completed.isCompleted) {
          completed.complete(run);
        }
      });
      addTearDown(subscription.cancel);

      await coordinator.startFullScan();
      final run = await completed.future.timeout(const Duration(seconds: 3));

      expect(run.status, ScanRunStatus.completed);
      expect(folderMappingService.buildSuggestedCellsCallCount, 1);
      expect(folderMappingService.explainPlacementCallCount, 3);
    },
  );

  test(
    'RealScanCoordinator preserves limited scope counts and results',
    () async {
      final mediaLibraryService = _ScopeAwareMediaLibraryService(
        allAssets: _FakeMediaLibraryService._assets,
        limitedAssets: _FakeMediaLibraryService._assets.take(2).toList(),
      );
      final folderCellRepository = InMemoryFolderCellRepository(
        seedCells: const [],
      );
      final coordinator = RealScanCoordinator(
        mediaLibraryService: mediaLibraryService,
        classificationService: _FakeClassificationService(),
        folderMappingService: KeywordFolderMappingService(
          now: () => DateTime(2026, 4, 18),
        ),
        classificationRepository: InMemoryClassificationRepository(),
        manualOverrideRepository: InMemoryManualOverrideRepository(),
        mediaAssetRepository: InMemoryMediaAssetRepository(
          seedAssets: const [],
        ),
        folderCellRepository: folderCellRepository,
        scanRunRepository: InMemoryScanRunRepository(seedRuns: const []),
        pageSize: 4,
        now: () => DateTime(2026, 4, 18, 12),
      );

      final completed = Completer<ScanRun>();
      final subscription = coordinator.watchActiveRun().listen((run) {
        if (run.isTerminal && !completed.isCompleted) {
          completed.complete(run);
        }
      });
      addTearDown(subscription.cancel);

      await coordinator.startFullScan(scope: const ScanScope.limitedPhotos());
      final run = await completed.future.timeout(const Duration(seconds: 3));
      final videosCell = await folderCellRepository.getCellById('videos');
      final petsCell = await folderCellRepository.getCellById('pets');

      expect(run.status, ScanRunStatus.completed);
      expect(run.discoveredAssetCount, 2);
      expect(run.classifiedAssetCount, 2);
      expect(mediaLibraryService.countScopes, [ScanScopeKind.limitedPhotos]);
      expect(
        mediaLibraryService.fetchScopes,
        everyElement(ScanScopeKind.limitedPhotos),
      );
      expect(videosCell?.assetIds, ['asset_2']);
      expect(petsCell?.assetIds, ['asset_1']);
    },
  );
}

class _FakeMediaLibraryService implements MediaLibraryService {
  static final List<MediaAsset> _assets = [
    MediaAsset(
      id: 'asset_1',
      type: MediaAssetType.image,
      createdAt: DateTime(2026, 4, 10),
      modifiedAt: DateTime(2026, 4, 10),
      width: 3024,
      height: 4032,
      originalFilename: 'IMG_0001.HEIC',
    ),
    MediaAsset(
      id: 'asset_2',
      type: MediaAssetType.video,
      createdAt: DateTime(2026, 4, 11),
      modifiedAt: DateTime(2026, 4, 11),
      width: 1920,
      height: 1080,
      duration: const Duration(seconds: 12),
      originalFilename: 'IMG_0002.MOV',
    ),
    MediaAsset(
      id: 'asset_3',
      type: MediaAssetType.image,
      createdAt: DateTime(2026, 4, 12),
      modifiedAt: DateTime(2026, 4, 12),
      width: 3024,
      height: 4032,
      originalFilename: 'IMG_0003.HEIC',
    ),
  ];

  @override
  Future<List<MediaAsset>> fetchAssets({
    DateTime? updatedAfter,
    int page = 0,
    int pageSize = 200,
    ScanScope scope = const ScanScope.allPhotos(),
  }) async {
    final start = page * pageSize;
    if (start >= _assets.length) {
      return const [];
    }

    final end = start + pageSize < _assets.length
        ? start + pageSize
        : _assets.length;
    return _assets.sublist(start, end);
  }

  @override
  Future<MediaAsset?> getAssetById(String assetId) async {
    for (final asset in _assets) {
      if (asset.id == assetId) {
        return asset;
      }
    }

    return null;
  }

  @override
  Future<List<MediaAlbum>> getAvailableAlbums({int limit = 24}) async {
    return const [];
  }

  @override
  Future<int> getEstimatedAssetCount({
    ScanScope scope = const ScanScope.allPhotos(),
  }) async => _assets.length;
}

class _FakeClassificationService extends ClassificationService {
  static final Map<String, List<ClassificationLabel>> _labelsByAssetId = {
    'asset_1': [
      ClassificationLabel(
        id: 'dog',
        key: 'dog',
        displayName: 'dog',
        confidence: 0.93,
        source: ClassificationLabelSource.onDeviceModel,
        createdAt: DateTime(2026, 4, 18, 12),
        modelIdentifier: 'test',
      ),
    ],
    'asset_3': [
      ClassificationLabel(
        id: 'food',
        key: 'food',
        displayName: 'food',
        confidence: 0.88,
        source: ClassificationLabelSource.onDeviceModel,
        createdAt: DateTime(2026, 4, 18, 12),
        modelIdentifier: 'test',
      ),
    ],
  };

  @override
  Future<ClassificationOutcome> classifyAssetDetailed(MediaAsset asset) async {
    final labels = _labelsByAssetId[asset.id] ?? const [];
    return ClassificationOutcome(
      assetId: asset.id,
      status: labels.isEmpty
          ? ClassificationOutcomeStatus.noLabelsReturned
          : ClassificationOutcomeStatus.succeeded,
      labels: labels,
      classificationRan: true,
      imagePreparationSucceeded: true,
      noLabelsReturned: labels.isEmpty,
      modelIdentifier: labels.isEmpty ? null : labels.first.modelIdentifier,
    );
  }
}

class _CountingClassificationService extends ClassificationService {
  _CountingClassificationService({
    required Map<String, List<ClassificationLabel>> labelsByAssetId,
  }) : _labelsByAssetId = labelsByAssetId;

  final Map<String, List<ClassificationLabel>> _labelsByAssetId;
  int callCount = 0;

  @override
  Future<ClassificationOutcome> classifyAssetDetailed(MediaAsset asset) async {
    callCount += 1;
    final labels = _labelsByAssetId[asset.id] ?? const [];
    return ClassificationOutcome(
      assetId: asset.id,
      status: labels.isEmpty
          ? ClassificationOutcomeStatus.noLabelsReturned
          : ClassificationOutcomeStatus.succeeded,
      labels: labels,
      classificationRan: true,
      imagePreparationSucceeded: true,
      noLabelsReturned: labels.isEmpty,
      modelIdentifier: labels.isEmpty ? null : labels.first.modelIdentifier,
    );
  }
}

class _CountingFolderMappingService implements FolderMappingService {
  _CountingFolderMappingService(this._delegate);

  final FolderMappingService _delegate;
  int buildSuggestedCellsCallCount = 0;
  int explainPlacementCallCount = 0;

  @override
  Future<List<FolderCell>> buildSuggestedCells({
    required List<MediaAsset> assets,
    required Map<String, List<ClassificationLabel>> labelsByAssetId,
    List<ManualOverride> overrides = const [],
  }) {
    buildSuggestedCellsCallCount += 1;
    return _delegate.buildSuggestedCells(
      assets: assets,
      labelsByAssetId: labelsByAssetId,
      overrides: overrides,
    );
  }

  @override
  AssetMappingExplanation explainPlacement({
    required MediaAsset asset,
    required List<ClassificationLabel> labels,
  }) {
    explainPlacementCallCount += 1;
    return _delegate.explainPlacement(asset: asset, labels: labels);
  }
}

class _ConfigurableMediaLibraryService implements MediaLibraryService {
  _ConfigurableMediaLibraryService(this._assets);

  final List<MediaAsset> _assets;

  @override
  Future<List<MediaAsset>> fetchAssets({
    DateTime? updatedAfter,
    int page = 0,
    int pageSize = 200,
    ScanScope scope = const ScanScope.allPhotos(),
  }) async {
    final start = page * pageSize;
    if (start >= _assets.length) {
      return const [];
    }

    final end = start + pageSize < _assets.length
        ? start + pageSize
        : _assets.length;
    return _assets.sublist(start, end);
  }

  @override
  Future<MediaAsset?> getAssetById(String assetId) async {
    for (final asset in _assets) {
      if (asset.id == assetId) {
        return asset;
      }
    }
    return null;
  }

  @override
  Future<List<MediaAlbum>> getAvailableAlbums({int limit = 24}) async {
    return const [];
  }

  @override
  Future<int> getEstimatedAssetCount({
    ScanScope scope = const ScanScope.allPhotos(),
  }) async => _assets.length;
}

class _ScopeAwareMediaLibraryService implements MediaLibraryService {
  _ScopeAwareMediaLibraryService({
    required List<MediaAsset> allAssets,
    required List<MediaAsset> limitedAssets,
  }) : _allAssets = allAssets,
       _limitedAssets = limitedAssets;

  final List<MediaAsset> _allAssets;
  final List<MediaAsset> _limitedAssets;
  final List<ScanScopeKind> fetchScopes = [];
  final List<ScanScopeKind> countScopes = [];

  @override
  Future<List<MediaAsset>> fetchAssets({
    DateTime? updatedAfter,
    int page = 0,
    int pageSize = 200,
    ScanScope scope = const ScanScope.allPhotos(),
  }) async {
    fetchScopes.add(scope.kind);
    final source = scope.kind == ScanScopeKind.limitedPhotos
        ? _limitedAssets
        : _allAssets;
    final start = page * pageSize;
    if (start >= source.length) {
      return const [];
    }

    final end = start + pageSize < source.length
        ? start + pageSize
        : source.length;
    return source.sublist(start, end);
  }

  @override
  Future<MediaAsset?> getAssetById(String assetId) async {
    for (final asset in [..._allAssets, ..._limitedAssets]) {
      if (asset.id == assetId) {
        return asset;
      }
    }
    return null;
  }

  @override
  Future<List<MediaAlbum>> getAvailableAlbums({int limit = 24}) async {
    return const [];
  }

  @override
  Future<int> getEstimatedAssetCount({
    ScanScope scope = const ScanScope.allPhotos(),
  }) async {
    countScopes.add(scope.kind);
    return scope.kind == ScanScopeKind.limitedPhotos
        ? _limitedAssets.length
        : _allAssets.length;
  }
}
