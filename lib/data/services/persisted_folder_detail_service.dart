import '../../application/repositories/classification_repository.dart';
import '../../application/models/folder_detail_item.dart';
import '../../application/models/folder_detail_snapshot.dart';
import '../../application/repositories/folder_cell_repository.dart';
import '../../application/repositories/media_asset_repository.dart';
import '../../application/services/folder_detail_service.dart';
import '../../application/services/folder_mapping_service.dart';
import '../../domain/entities/media_asset.dart';
import '../repositories/local_classification_repository.dart';
import '../repositories/local_folder_cell_repository.dart';
import '../repositories/local_media_asset_repository.dart';
import 'keyword_folder_mapping_service.dart';
import 'local_scan_result_store.dart';

class PersistedFolderDetailService implements FolderDetailService {
  PersistedFolderDetailService({
    required FolderCellRepository folderCellRepository,
    required MediaAssetRepository mediaAssetRepository,
    required ClassificationRepository classificationRepository,
    required FolderMappingService folderMappingService,
  }) : _folderCellRepository = folderCellRepository,
       _mediaAssetRepository = mediaAssetRepository,
       _classificationRepository = classificationRepository,
       _folderMappingService = folderMappingService;

  final FolderCellRepository _folderCellRepository;
  final MediaAssetRepository _mediaAssetRepository;
  final ClassificationRepository _classificationRepository;
  final FolderMappingService _folderMappingService;

  factory PersistedFolderDetailService.standard() {
    final store = LocalScanResultStore();
    return PersistedFolderDetailService(
      folderCellRepository: LocalFolderCellRepository(store: store),
      mediaAssetRepository: LocalMediaAssetRepository(store: store),
      classificationRepository: LocalClassificationRepository(store: store),
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
    final allAssets = await _mediaAssetRepository.getAllAssets();
    final assetsById = {for (final asset in allAssets) asset.id: asset};
    final items = <FolderDetailItem>[];

    for (final assetId in cell.assetIds) {
      final asset = assetsById[assetId];
      if (asset == null) {
        continue;
      }

      final explanation = _folderMappingService.explainPlacement(
        asset: asset,
        labels: labelsByAssetId[asset.id] ?? const [],
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
