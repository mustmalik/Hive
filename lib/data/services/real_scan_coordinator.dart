import 'dart:async';

import '../../application/models/classification_outcome.dart';
import '../../application/models/scan_scope.dart';
import '../../application/repositories/classification_repository.dart';
import '../../application/repositories/folder_cell_repository.dart';
import '../../application/repositories/media_asset_repository.dart';
import '../../application/repositories/scan_run_repository.dart';
import '../../application/services/classification_service.dart';
import '../../application/services/folder_mapping_service.dart';
import '../../application/services/media_library_service.dart';
import '../../application/services/scan_coordinator.dart';
import '../../domain/entities/classification_label.dart';
import '../../domain/entities/folder_cell.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/scan_run.dart';
import '../repositories/local_classification_repository.dart';
import '../repositories/local_folder_cell_repository.dart';
import '../repositories/local_media_asset_repository.dart';
import '../repositories/local_scan_run_repository.dart';
import 'ios_vision_classification_service.dart';
import 'keyword_folder_mapping_service.dart';
import 'local_scan_result_store.dart';
import 'photo_manager_media_library_service.dart';

class RealScanCoordinator implements ScanCoordinator {
  RealScanCoordinator({
    required MediaLibraryService mediaLibraryService,
    required ClassificationService classificationService,
    required FolderMappingService folderMappingService,
    required ClassificationRepository classificationRepository,
    required MediaAssetRepository mediaAssetRepository,
    required FolderCellRepository folderCellRepository,
    required ScanRunRepository scanRunRepository,
    int pageSize = 24,
    DateTime Function()? now,
  }) : _mediaLibraryService = mediaLibraryService,
       _classificationService = classificationService,
       _folderMappingService = folderMappingService,
       _classificationRepository = classificationRepository,
       _mediaAssetRepository = mediaAssetRepository,
       _folderCellRepository = folderCellRepository,
       _scanRunRepository = scanRunRepository,
       _pageSize = pageSize,
       _now = now ?? DateTime.now;

  final MediaLibraryService _mediaLibraryService;
  final ClassificationService _classificationService;
  final FolderMappingService _folderMappingService;
  final ClassificationRepository _classificationRepository;
  final MediaAssetRepository _mediaAssetRepository;
  final FolderCellRepository _folderCellRepository;
  final ScanRunRepository _scanRunRepository;
  final int _pageSize;
  final DateTime Function() _now;
  final StreamController<ScanRun> _controller =
      StreamController<ScanRun>.broadcast();

  ScanRun? _activeRun;
  Future<void>? _activeTask;
  bool _cancelRequested = false;

  factory RealScanCoordinator.seeded() {
    final store = LocalScanResultStore();

    return RealScanCoordinator(
      mediaLibraryService: const PhotoManagerMediaLibraryService(),
      classificationService: IosVisionClassificationService(),
      folderMappingService: KeywordFolderMappingService(),
      classificationRepository: LocalClassificationRepository(store: store),
      mediaAssetRepository: LocalMediaAssetRepository(store: store),
      folderCellRepository: LocalFolderCellRepository(store: store),
      scanRunRepository: LocalScanRunRepository(store: store),
    );
  }

  @override
  Future<void> cancelActiveRun() async {
    final run = _activeRun;
    if (run == null || run.isTerminal) {
      return;
    }

    _cancelRequested = true;
    await _activeTask;
  }

  @override
  Future<ScanRun?> getLatestRun() {
    return _scanRunRepository.getLatestRun();
  }

  @override
  Future<ScanRun> startFullScan({
    ScanScope scope = const ScanScope.allPhotos(),
  }) async {
    final currentRun = _activeRun;
    if (currentRun != null && !currentRun.isTerminal) {
      return currentRun;
    }

    final now = _now();
    final totalAssets = await _resolveTotalAssets(scope: scope);
    final queuedRun = ScanRun(
      id: 'scan_${now.millisecondsSinceEpoch}',
      status: ScanRunStatus.queued,
      startedAt: now,
      discoveredAssetCount: totalAssets,
      classifiedAssetCount: 0,
      generatedCellCount: 0,
      currentStageLabel: 'Preparing your library',
      currentItemTitle: 'Connecting to Apple Photos',
      latestDetectedCellName: 'Unsorted',
    );

    _cancelRequested = false;
    await _emitRun(queuedRun);
    _activeTask = _performScan(queuedRun, scope: scope);
    unawaited(_activeTask);
    return queuedRun;
  }

  @override
  Stream<ScanRun> watchActiveRun() => _controller.stream;

  Future<void> _performScan(
    ScanRun startingRun, {
    required ScanScope scope,
  }) async {
    final processedAssets = <MediaAsset>[];
    final labelsByAssetId = <String, List<ClassificationLabel>>{};
    final outcomesByAssetId = <String, ClassificationOutcome>{};
    var processedCount = 0;
    var page = 0;
    var latestDetectedCellName = startingRun.latestDetectedCellName;
    var generatedCellCount = 0;

    try {
      while (!_cancelRequested) {
        final batch = await _mediaLibraryService.fetchAssets(
          page: page,
          pageSize: _pageSize,
          scope: scope,
        );

        if (batch.isEmpty) {
          break;
        }

        for (final asset in batch) {
          if (_cancelRequested) {
            break;
          }

          processedAssets.add(asset);
          final currentItemTitle = _resolveCurrentItemTitle(
            asset,
            ordinal: processedCount + 1,
          );

          final outcome = await _classifySafely(asset);
          final labels = outcome.labels;
          labelsByAssetId[asset.id] = labels;
          outcomesByAssetId[asset.id] = outcome;

          final cells = await _folderMappingService.buildSuggestedCells(
            assets: processedAssets,
            labelsByAssetId: labelsByAssetId,
          );

          processedCount += 1;
          generatedCellCount = cells.length;
          latestDetectedCellName = _resolveLatestDetectedCellName(
            asset: asset,
            labels: labels,
            cells: cells,
            fallback: latestDetectedCellName,
          );

          final stageLabel = _resolveStageLabel(
            processedCount: processedCount,
            totalCountHint: startingRun.discoveredAssetCount,
            asset: asset,
            labels: labels,
          );

          await _emitRun(
            ScanRun(
              id: startingRun.id,
              status: ScanRunStatus.running,
              startedAt: startingRun.startedAt,
              discoveredAssetCount: startingRun.discoveredAssetCount,
              classifiedAssetCount: processedCount,
              generatedCellCount: generatedCellCount,
              currentStageLabel: stageLabel,
              currentItemTitle: currentItemTitle,
              latestDetectedCellName: latestDetectedCellName,
            ),
          );
        }

        if (batch.length < _pageSize) {
          break;
        }

        page += 1;
      }

      if (_cancelRequested) {
        final current = _activeRun ?? startingRun;
        await _emitRun(
          ScanRun(
            id: current.id,
            status: ScanRunStatus.canceled,
            startedAt: current.startedAt,
            completedAt: _now(),
            discoveredAssetCount: current.discoveredAssetCount,
            classifiedAssetCount: current.classifiedAssetCount,
            generatedCellCount: current.generatedCellCount,
            currentStageLabel: 'Scan canceled',
            currentItemTitle: current.currentItemTitle,
            latestDetectedCellName: current.latestDetectedCellName,
          ),
        );
        return;
      }

      final finalCells = await _folderMappingService.buildSuggestedCells(
        assets: processedAssets,
        labelsByAssetId: labelsByAssetId,
      );

      await _persistResults(
        assets: processedAssets,
        cells: finalCells,
        outcomesByAssetId: outcomesByAssetId,
      );

      await _emitRun(
        ScanRun(
          id: startingRun.id,
          status: ScanRunStatus.completed,
          startedAt: startingRun.startedAt,
          completedAt: _now(),
          discoveredAssetCount: processedCount,
          classifiedAssetCount: processedCount,
          generatedCellCount: finalCells.length,
          currentStageLabel: 'Cells ready',
          currentItemTitle: 'Finishing your HIVE overview',
          latestDetectedCellName: latestDetectedCellName ?? 'Unsorted',
        ),
      );
    } catch (error) {
      final current = _activeRun ?? startingRun;
      await _emitRun(
        ScanRun(
          id: current.id,
          status: ScanRunStatus.failed,
          startedAt: current.startedAt,
          completedAt: _now(),
          discoveredAssetCount: current.discoveredAssetCount,
          classifiedAssetCount: current.classifiedAssetCount,
          generatedCellCount: current.generatedCellCount,
          errorMessage: 'Unable to finish this scan safely.',
          currentStageLabel: 'Scan paused',
          currentItemTitle: current.currentItemTitle,
          latestDetectedCellName: current.latestDetectedCellName,
        ),
      );
    } finally {
      _cancelRequested = false;
      _activeTask = null;
    }
  }

  Future<void> _persistResults({
    required List<MediaAsset> assets,
    required List<FolderCell> cells,
    required Map<String, ClassificationOutcome> outcomesByAssetId,
  }) async {
    await _classificationRepository.clear();
    for (final outcome in outcomesByAssetId.values) {
      await _classificationRepository.saveOutcome(outcome);
    }
    await _mediaAssetRepository.clear();
    await _mediaAssetRepository.upsertAssets(assets);
    await _folderCellRepository.clear();
    await _folderCellRepository.saveCells(cells);
  }

  Future<ClassificationOutcome> _classifySafely(MediaAsset asset) async {
    if (!_isClassifiable(asset)) {
      return ClassificationOutcome(
        assetId: asset.id,
        status: ClassificationOutcomeStatus.unsupportedAsset,
        labels: const [],
        failureReason:
            'This asset type is not currently classifiable on device.',
        failureStage: 'load_image_data',
        failureCode: 'unsupported_asset_type',
        classificationRan: false,
        imagePreparationSucceeded: false,
        noLabelsReturned: false,
      );
    }

    try {
      return await _classificationService.classifyAssetDetailed(asset);
    } catch (_) {
      return ClassificationOutcome(
        assetId: asset.id,
        status: ClassificationOutcomeStatus.requestFailed,
        labels: const [],
        failureReason: 'The on-device classifier could not finish this asset.',
        failureStage: 'vision_execution',
        failureCode: 'scan_coordinator_classification_error',
        classificationRan: false,
        imagePreparationSucceeded: false,
        noLabelsReturned: false,
      );
    }
  }

  bool _isClassifiable(MediaAsset asset) {
    return asset.type == MediaAssetType.image ||
        asset.type == MediaAssetType.livePhoto ||
        asset.type == MediaAssetType.screenshot;
  }

  Future<void> _emitRun(ScanRun run) async {
    _activeRun = run;
    await _scanRunRepository.saveRun(run);
    if (!_controller.isClosed) {
      _controller.add(run);
    }
  }

  Future<int> _resolveTotalAssets({required ScanScope scope}) async {
    try {
      final total = await _mediaLibraryService.getEstimatedAssetCount(
        scope: scope,
      );
      return total;
    } catch (_) {
      return 0;
    }
  }

  String _resolveCurrentItemTitle(MediaAsset asset, {required int ordinal}) {
    final title = asset.originalFilename;
    if (title != null && title.trim().isNotEmpty) {
      return title;
    }

    return switch (asset.type) {
      MediaAssetType.video => 'Video $ordinal',
      MediaAssetType.livePhoto => 'Live Photo $ordinal',
      MediaAssetType.screenshot => 'Screenshot $ordinal',
      MediaAssetType.image => 'Photo $ordinal',
      MediaAssetType.other => 'Asset $ordinal',
    };
  }

  String _resolveStageLabel({
    required int processedCount,
    required int totalCountHint,
    required MediaAsset asset,
    required List<ClassificationLabel> labels,
  }) {
    if (processedCount <= 3) {
      return 'Reading library metadata';
    }

    final progress = totalCountHint <= 0 ? 0 : processedCount / totalCountHint;
    if (progress >= 0.85) {
      return 'Finalizing your cell suggestions';
    }

    if (_isClassifiable(asset)) {
      return labels.isEmpty
          ? 'Reviewing local image signals'
          : 'Classifying images on device';
    }

    return 'Shaping placeholder cells';
  }

  String _resolveLatestDetectedCellName({
    required MediaAsset asset,
    required List<ClassificationLabel> labels,
    required List<FolderCell> cells,
    required String? fallback,
  }) {
    for (final cell in cells) {
      if (cell.coverAssetId == asset.id || cell.assetIds.contains(asset.id)) {
        return cell.name;
      }
    }

    if (labels.isNotEmpty) {
      return fallback ?? 'Unsorted';
    }

    return fallback ?? 'Unsorted';
  }
}
