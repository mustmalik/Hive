import '../../application/repositories/classification_repository.dart';
import '../../application/models/folder_detail_item.dart';
import '../../application/models/folder_detail_snapshot.dart';
import '../../application/models/asset_mapping_explanation.dart';
import '../../application/repositories/folder_cell_repository.dart';
import '../../application/repositories/manual_override_repository.dart';
import '../../application/repositories/media_asset_repository.dart';
import '../../application/repositories/placement_audit_repository.dart';
import '../../application/services/folder_detail_service.dart';
import '../../application/services/folder_mapping_service.dart';
import '../../domain/entities/folder_cell.dart';
import '../../domain/entities/media_asset.dart';
import '../repositories/local_classification_repository.dart';
import '../repositories/local_folder_cell_repository.dart';
import '../repositories/local_manual_override_repository.dart';
import '../repositories/local_media_asset_repository.dart';
import '../repositories/local_placement_audit_repository.dart';
import 'keyword_folder_mapping_service.dart';
import 'local_scan_result_store.dart';
import 'placement/placement_definitions.dart';
import 'resolved_cell_membership.dart';
import 'result_pipeline_debug.dart';

class PersistedFolderDetailService implements FolderDetailService {
  PersistedFolderDetailService({
    required FolderCellRepository folderCellRepository,
    required MediaAssetRepository mediaAssetRepository,
    required ClassificationRepository classificationRepository,
    required ManualOverrideRepository manualOverrideRepository,
    required FolderMappingService folderMappingService,
    required PlacementAuditRepository placementAuditRepository,
  }) : _folderCellRepository = folderCellRepository,
       _mediaAssetRepository = mediaAssetRepository,
       _classificationRepository = classificationRepository,
       _manualOverrideRepository = manualOverrideRepository,
       _folderMappingService = folderMappingService,
       _placementAuditRepository = placementAuditRepository;

  final FolderCellRepository _folderCellRepository;
  final MediaAssetRepository _mediaAssetRepository;
  final ClassificationRepository _classificationRepository;
  final ManualOverrideRepository _manualOverrideRepository;
  final FolderMappingService _folderMappingService;
  final PlacementAuditRepository _placementAuditRepository;

  factory PersistedFolderDetailService.standard() {
    final store = LocalScanResultStore();
    return PersistedFolderDetailService(
      folderCellRepository: LocalFolderCellRepository(store: store),
      mediaAssetRepository: LocalMediaAssetRepository(store: store),
      classificationRepository: LocalClassificationRepository(store: store),
      manualOverrideRepository: LocalManualOverrideRepository(store: store),
      folderMappingService: KeywordFolderMappingService(),
      placementAuditRepository: LocalPlacementAuditRepository(store: store),
    );
  }

  @override
  Future<FolderDetailSnapshot?> loadCell(String cellId) async {
    final persistedCell = await _folderCellRepository.getCellById(cellId);
    final cell = persistedCell ?? _syntheticCellForId(cellId);
    if (cell == null) {
      return null;
    }

    final allAssets = await _mediaAssetRepository.getAllAssets();
    final assetIds = allAssets.map((asset) => asset.id).toList(growable: false);
    final labelsByAssetId = await _classificationRepository
        .getLabelsForAssetIds(assetIds);
    final outcomesByAssetId = await _classificationRepository
        .getOutcomesForAssetIds(assetIds);
    final auditEntries = await _placementAuditRepository.getRecentAuditEntries(
      500,
    );
    final auditedFinalCellByAssetId = <String, String>{};
    for (final entry in auditEntries) {
      auditedFinalCellByAssetId.putIfAbsent(entry.assetId, () => entry.finalCell);
    }
    final manualOverrides = latestIncludeOverridesByAssetId(
      await _manualOverrideRepository.getAllOverrides(),
    );
    final items = <FolderDetailItem>[];

    for (final asset in allAssets) {
      final labels = labelsByAssetId[asset.id] ?? const [];
      final override = manualOverrides[asset.id];
      final authoritativeCellId =
          override?.cellId ??
          auditedFinalCellByAssetId[asset.id] ??
          resolveCellIdForAsset(
            asset: asset,
            labels: labels,
            folderMappingService: _folderMappingService,
            override: null,
          );
      if (authoritativeCellId != cell.id) {
        continue;
      }

      AssetMappingExplanation? explanation;
      if (override?.cellId != null) {
        explanation = resolveCellExplanationForAsset(
          selectedCellId: cell.id,
          selectedCellName: cell.name,
          asset: asset,
          labels: labels,
          folderMappingService: _folderMappingService,
          override: override,
        );
      } else if (_folderMappingService is KeywordFolderMappingService) {
        // Use async placement so structural-only meme routes stay stable on reload.
        final asyncExplanation =
            await _folderMappingService.explainPlacementAsync(
              asset: asset,
              labels: labels,
            );
        explanation =
            asyncExplanation.cellId == cell.id
                ? asyncExplanation
                : AssetMappingExplanation(
                    cellId: cell.id,
                    cellName: cell.name,
                    score: 1.0,
                    usedFallback: false,
                    topLabels: labels,
                    fallbackOrDebugReasons: const [
                      'authoritative persisted placement used',
                    ],
                  );
      } else {
        explanation = AssetMappingExplanation(
          cellId: cell.id,
          cellName: cell.name,
          score: 1.0,
          usedFallback: false,
          topLabels: labels,
          fallbackOrDebugReasons: const [
            'authoritative persisted placement used',
          ],
        );
      }

      items.add(
        FolderDetailItem(
          asset: asset,
          title: asset.originalFilename ?? _fallbackTitle(asset.id),
          subtitle: _buildSubtitle(asset),
          mappingExplanation: explanation,
          classificationOutcome: outcomesByAssetId[asset.id],
        ),
      );
    }

    if (persistedCell == null && items.isEmpty) {
      return null;
    }

    debugResultsLog(
      'folder detail cell=$cellId persistedCell=${persistedCell != null} '
      'persistedAssets=${assetIds.length} rendered=${items.length} '
      'renderedIds=${debugIdSet(items.map((item) => item.asset.id))}',
    );

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

  FolderCell? _syntheticCellForId(String cellId) {
    final rule = KeywordPlacementDefinitions.ruleForCellId(cellId);
    if (rule == null) {
      return null;
    }

    final now = DateTime.now();
    return FolderCell(
      id: rule.cellId,
      name: rule.cellName,
      origin: FolderCellOrigin.suggested,
      createdAt: now,
      updatedAt: now,
      description: rule.description,
      isPinned: rule.featured,
    );
  }
}
