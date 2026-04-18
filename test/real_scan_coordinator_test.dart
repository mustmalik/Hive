import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter_v1/application/services/classification_service.dart';
import 'package:hive_flutter_v1/application/services/media_library_service.dart';
import 'package:hive_flutter_v1/data/repositories/in_memory_scan_run_repository.dart';
import 'package:hive_flutter_v1/data/services/keyword_folder_mapping_service.dart';
import 'package:hive_flutter_v1/data/services/real_scan_coordinator.dart';
import 'package:hive_flutter_v1/domain/entities/classification_label.dart';
import 'package:hive_flutter_v1/domain/entities/media_asset.dart';
import 'package:hive_flutter_v1/domain/entities/scan_run.dart';

void main() {
  test(
    'RealScanCoordinator emits real batched progress and completes',
    () async {
      final coordinator = RealScanCoordinator(
        mediaLibraryService: _FakeMediaLibraryService(),
        classificationService: _FakeClassificationService(),
        folderMappingService: KeywordFolderMappingService(
          now: () => DateTime(2026, 4, 18),
        ),
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
  Future<int> getEstimatedAssetCount() async => _assets.length;
}

class _FakeClassificationService implements ClassificationService {
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
  Future<List<ClassificationLabel>> classifyAsset(MediaAsset asset) async {
    return _labelsByAssetId[asset.id] ?? const [];
  }

  @override
  Future<Map<String, List<ClassificationLabel>>> classifyAssets(
    List<MediaAsset> assets,
  ) async {
    return {for (final asset in assets) asset.id: await classifyAsset(asset)};
  }
}
