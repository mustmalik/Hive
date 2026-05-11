import 'package:flutter/foundation.dart';

import '../../application/models/asset_mapping_explanation.dart';
import '../../application/models/classification_backend.dart';
import '../../application/models/classification_outcome.dart';
import '../../application/models/folder_detail_item.dart';
import '../../application/repositories/classification_repository.dart';
import '../../application/repositories/folder_cell_repository.dart';
import '../../application/repositories/manual_override_repository.dart';
import '../../application/repositories/media_asset_repository.dart';
import '../../application/services/asset_reclassification_service.dart';
import '../../application/services/classification_service.dart';
import '../../application/services/folder_mapping_service.dart';
import '../../domain/entities/classification_label.dart';
import '../../domain/entities/folder_cell.dart';
import '../../domain/entities/manual_override.dart';
import '../../domain/entities/media_asset.dart';
import '../repositories/local_classification_repository.dart';
import '../repositories/local_folder_cell_repository.dart';
import '../repositories/local_manual_override_repository.dart';
import '../repositories/local_media_asset_repository.dart';
import 'classification_service_factory.dart';
import 'keyword_folder_mapping_service.dart';
import 'local_scan_result_store.dart';
import 'resolved_cell_membership.dart';

class PersistedAssetReclassificationService
    implements AssetReclassificationService {
  PersistedAssetReclassificationService({
    required ClassificationService classificationService,
    required ClassificationRepository classificationRepository,
    required MediaAssetRepository mediaAssetRepository,
    required FolderCellRepository folderCellRepository,
    required ManualOverrideRepository manualOverrideRepository,
    required FolderMappingService folderMappingService,
  }) : _classificationService = classificationService,
       _classificationRepository = classificationRepository,
       _mediaAssetRepository = mediaAssetRepository,
       _folderCellRepository = folderCellRepository,
       _manualOverrideRepository = manualOverrideRepository,
       _folderMappingService = folderMappingService;

  final ClassificationService _classificationService;
  final ClassificationRepository _classificationRepository;
  final MediaAssetRepository _mediaAssetRepository;
  final FolderCellRepository _folderCellRepository;
  final ManualOverrideRepository _manualOverrideRepository;
  final FolderMappingService _folderMappingService;

  factory PersistedAssetReclassificationService.standard({
    ClassificationBackend? classificationBackend,
  }) {
    final store = LocalScanResultStore();
    return PersistedAssetReclassificationService(
      classificationService: ClassificationServiceFactory.create(
        backend: classificationBackend,
      ),
      classificationRepository: LocalClassificationRepository(store: store),
      mediaAssetRepository: LocalMediaAssetRepository(store: store),
      folderCellRepository: LocalFolderCellRepository(store: store),
      manualOverrideRepository: LocalManualOverrideRepository(store: store),
      folderMappingService: KeywordFolderMappingService(),
    );
  }

  @override
  Future<FolderDetailItem?> reclassifyAsset({required String assetId}) async {
    final asset = await _mediaAssetRepository.getAssetById(assetId);
    if (asset == null) {
      return null;
    }

    await _classificationRepository.deleteOutcomeForAsset(assetId);
    await _primeStructuralSignals(asset);

    final outcome = await _classifySafely(asset);
    await _classificationRepository.saveOutcome(outcome);

    final assets = await _mediaAssetRepository.getAllAssets();
    final assetIds = assets.map((item) => item.id).toList(growable: false);
    final labelsByAssetId = await _classificationRepository
        .getLabelsForAssetIds(assetIds);
    final overrides = await _manualOverrideRepository.getAllOverrides();
    final cells = await _folderMappingService.buildSuggestedCells(
      assets: assets,
      labelsByAssetId: labelsByAssetId,
      overrides: overrides,
    );

    await _folderCellRepository.replaceAll(cells);

    final latestOverrides = latestIncludeOverridesByAssetId(overrides);
    final explanation = _resolveCurrentExplanation(
      asset: asset,
      outcome: outcome,
      cells: cells,
      override: latestOverrides[asset.id],
    );

    return FolderDetailItem(
      asset: asset,
      title: asset.originalFilename ?? _fallbackTitle(asset.id),
      subtitle: _buildSubtitle(asset),
      mappingExplanation: explanation,
      classificationOutcome: outcome,
    );
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

    if (kDebugMode) {
      debugPrint(
        '[HIVE-ENGINE] Using '
        '${ClassificationServiceFactory.engineNameForService(_classificationService)} '
        'for labeling — mediaId=${asset.id}',
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
        failureCode: 'single_asset_reclassification_error',
        classificationRan: false,
        imagePreparationSucceeded: false,
        noLabelsReturned: false,
      );
    }
  }

  Future<void> _primeStructuralSignals(MediaAsset asset) async {
    if (!_isClassifiable(asset)) {
      return;
    }

    final folderMappingService = _folderMappingService;
    if (folderMappingService is! KeywordFolderMappingService) {
      return;
    }

    try {
      await folderMappingService.primeStructuralSignals(asset: asset);
    } catch (_) {
      return;
    }
  }

  bool _isClassifiable(MediaAsset asset) {
    return asset.type == MediaAssetType.image ||
        asset.type == MediaAssetType.livePhoto ||
        asset.type == MediaAssetType.screenshot;
  }

  AssetMappingExplanation _resolveCurrentExplanation({
    required MediaAsset asset,
    required ClassificationOutcome outcome,
    required List<FolderCell> cells,
    required ManualOverride? override,
  }) {
    final labels = outcome.labels;
    if (override?.cellId case final overrideCellId?) {
      var overrideCellName = _humanizeCellId(overrideCellId);
      for (final cell in cells) {
        if (cell.id == overrideCellId) {
          overrideCellName = cell.name;
          break;
        }
      }
      return AssetMappingExplanation(
        cellId: overrideCellId,
        cellName: overrideCellName,
        score: 1.5,
        usedFallback: false,
        topLabels: List<ClassificationLabel>.from(labels),
        matchedKeywords: const ['manual override'],
        isManualOverride: true,
      );
    }

    return _folderMappingService.explainPlacement(asset: asset, labels: labels);
  }

  String _buildSubtitle(MediaAsset asset) {
    final typeLabel = switch (asset.type) {
      MediaAssetType.video => 'Video',
      MediaAssetType.livePhoto => 'Live Photo',
      MediaAssetType.screenshot => 'Screenshot',
      MediaAssetType.image => 'Photo',
      MediaAssetType.other => 'Asset',
    };

    final date = asset.createdAt;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$typeLabel • ${date.year}-$month-$day';
  }

  String _fallbackTitle(String assetId) => 'Asset ${assetId.split('/').last}';

  String _humanizeCellId(String cellId) {
    final tokens = cellId
        .split('_')
        .where((token) => token.trim().isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return 'Cell';
    }

    return tokens
        .map((token) => '${token[0].toUpperCase()}${token.substring(1)}')
        .join(' ');
  }
}
