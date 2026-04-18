import 'dart:async';

import '../../application/repositories/scan_run_repository.dart';
import '../../application/services/classification_service.dart';
import '../../application/services/folder_mapping_service.dart';
import '../../application/services/media_library_service.dart';
import '../../application/services/scan_coordinator.dart';
import '../../domain/entities/classification_label.dart';
import '../../domain/entities/folder_cell.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/scan_run.dart';
import '../repositories/in_memory_scan_run_repository.dart';
import 'ios_vision_classification_service.dart';
import 'keyword_folder_mapping_service.dart';
import 'photo_manager_media_library_service.dart';

class RealScanCoordinator implements ScanCoordinator {
  RealScanCoordinator({
    required MediaLibraryService mediaLibraryService,
    required ClassificationService classificationService,
    required FolderMappingService folderMappingService,
    required ScanRunRepository scanRunRepository,
    int pageSize = 24,
    DateTime Function()? now,
  }) : _mediaLibraryService = mediaLibraryService,
       _classificationService = classificationService,
       _folderMappingService = folderMappingService,
       _scanRunRepository = scanRunRepository,
       _pageSize = pageSize,
       _now = now ?? DateTime.now;

  final MediaLibraryService _mediaLibraryService;
  final ClassificationService _classificationService;
  final FolderMappingService _folderMappingService;
  final ScanRunRepository _scanRunRepository;
  final int _pageSize;
  final DateTime Function() _now;
  final StreamController<ScanRun> _controller =
      StreamController<ScanRun>.broadcast();

  ScanRun? _activeRun;
  Future<void>? _activeTask;
  bool _cancelRequested = false;

  factory RealScanCoordinator.seeded() {
    return RealScanCoordinator(
      mediaLibraryService: const PhotoManagerMediaLibraryService(),
      classificationService: IosVisionClassificationService(),
      folderMappingService: KeywordFolderMappingService(),
      scanRunRepository: InMemoryScanRunRepository.seeded(),
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
  Future<ScanRun> startFullScan() async {
    final currentRun = _activeRun;
    if (currentRun != null && !currentRun.isTerminal) {
      return currentRun;
    }

    final now = _now();
    final totalAssets = await _resolveTotalAssets();
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
    _activeTask = _performScan(queuedRun);
    unawaited(_activeTask);
    return queuedRun;
  }

  @override
  Stream<ScanRun> watchActiveRun() => _controller.stream;

  Future<void> _performScan(ScanRun startingRun) async {
    final processedAssets = <MediaAsset>[];
    final labelsByAssetId = <String, List<ClassificationLabel>>{};
    var processedCount = 0;
    var page = 0;
    var latestDetectedCellName = startingRun.latestDetectedCellName;
    var generatedCellCount = 0;

    try {
      while (!_cancelRequested) {
        final batch = await _mediaLibraryService.fetchAssets(
          page: page,
          pageSize: _pageSize,
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

          final labels = await _classifySafely(asset);
          if (labels.isNotEmpty) {
            labelsByAssetId[asset.id] = labels;
          }

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

  Future<List<ClassificationLabel>> _classifySafely(MediaAsset asset) async {
    if (!_isClassifiable(asset)) {
      return const [];
    }

    try {
      return await _classificationService.classifyAsset(asset);
    } catch (_) {
      return const [];
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

  Future<int> _resolveTotalAssets() async {
    try {
      final total = await _mediaLibraryService.getEstimatedAssetCount();
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
