import '../../application/models/asset_mapping_explanation.dart';
import '../../application/repositories/classification_repository.dart';
import '../../application/models/folder_detail_item.dart';
import '../../application/models/folder_detail_snapshot.dart';
import '../../application/repositories/folder_cell_repository.dart';
import '../../application/repositories/manual_override_repository.dart';
import '../../application/repositories/media_asset_repository.dart';
import '../../application/services/folder_detail_service.dart';
import '../../application/services/folder_mapping_service.dart';
import '../../domain/entities/classification_label.dart';
import '../../domain/entities/manual_override.dart';
import '../../domain/entities/media_asset.dart';
import '../repositories/local_classification_repository.dart';
import '../repositories/local_folder_cell_repository.dart';
import '../repositories/local_manual_override_repository.dart';
import '../repositories/local_media_asset_repository.dart';
import 'keyword_folder_mapping_service.dart';
import 'local_scan_result_store.dart';

class PersistedFolderDetailService implements FolderDetailService {
  PersistedFolderDetailService({
    required FolderCellRepository folderCellRepository,
    required MediaAssetRepository mediaAssetRepository,
    required ClassificationRepository classificationRepository,
    required ManualOverrideRepository manualOverrideRepository,
    required FolderMappingService folderMappingService,
  }) : _folderCellRepository = folderCellRepository,
       _mediaAssetRepository = mediaAssetRepository,
       _classificationRepository = classificationRepository,
       _manualOverrideRepository = manualOverrideRepository,
       _folderMappingService = folderMappingService;

  final FolderCellRepository _folderCellRepository;
  final MediaAssetRepository _mediaAssetRepository;
  final ClassificationRepository _classificationRepository;
  final ManualOverrideRepository _manualOverrideRepository;
  final FolderMappingService _folderMappingService;

  factory PersistedFolderDetailService.standard() {
    final store = LocalScanResultStore();
    return PersistedFolderDetailService(
      folderCellRepository: LocalFolderCellRepository(store: store),
      mediaAssetRepository: LocalMediaAssetRepository(store: store),
      classificationRepository: LocalClassificationRepository(store: store),
      manualOverrideRepository: LocalManualOverrideRepository(store: store),
      folderMappingService: KeywordFolderMappingService(),
    );
  }

  @override
  Future<FolderDetailSnapshot?> loadCell(String cellId) async {
    final cell = await _folderCellRepository.getCellById(cellId);
    if (cell == null) {
      return null;
    }

    final labelsByAssetId = await _classificationRepository
        .getLabelsForAssetIds(cell.assetIds);
    final outcomesByAssetId = await _classificationRepository
        .getOutcomesForAssetIds(cell.assetIds);
    final manualOverrides = _latestIncludeOverrides(
      await _manualOverrideRepository.getAllOverrides(),
    );
    final allAssets = await _mediaAssetRepository.getAllAssets();
    final assetsById = {for (final asset in allAssets) asset.id: asset};
    final items = <FolderDetailItem>[];

    for (final assetId in cell.assetIds) {
      final asset = assetsById[assetId];
      if (asset == null) {
        continue;
      }

      final labels = labelsByAssetId[asset.id] ?? const [];
      final override = manualOverrides[asset.id];
      final explanation = override != null && override.cellId == cell.id
          ? _buildManualOverrideExplanation(
              cellId: cell.id,
              cellName: cell.name,
              labels: labels,
            )
          : _folderMappingService.explainPlacement(
              asset: asset,
              labels: labels,
            );

      items.add(
        FolderDetailItem(
          asset: asset,
          title: asset.originalFilename ?? _fallbackTitle(assetId),
          subtitle: _buildSubtitle(asset),
          mappingExplanation: explanation,
          classificationOutcome: outcomesByAssetId[asset.id],
        ),
      );
    }

    return FolderDetailSnapshot(
      cellId: cell.id,
      cellName: cell.name,
      description:
          cell.description ??
          '${cell.name} is a local HIVE cell built from your latest scan.',
      totalCount: items.length,
      items: items,
    );
  }

  Map<String, ManualOverride> _latestIncludeOverrides(
    List<ManualOverride> overrides,
  ) {
    final latestByAssetId = <String, ManualOverride>{};

    for (final override in overrides) {
      if (override.action != ManualOverrideAction.includeInCell ||
          override.cellId == null) {
        continue;
      }

      final existing = latestByAssetId[override.assetId];
      if (existing == null || override.createdAt.isAfter(existing.createdAt)) {
        latestByAssetId[override.assetId] = override;
      }
    }

    return latestByAssetId;
  }

  AssetMappingExplanation _buildManualOverrideExplanation({
    required String cellId,
    required String cellName,
    required List<ClassificationLabel> labels,
  }) {
    return AssetMappingExplanation(
      cellId: cellId,
      cellName: cellName,
      score: 1.5,
      usedFallback: false,
      topLabels: labels,
      matchedKeywords: const ['manual override'],
      isManualOverride: true,
    );
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
}
