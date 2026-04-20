import '../../application/models/hive_cell_category.dart';
import '../../application/repositories/classification_repository.dart';
import '../../application/repositories/folder_cell_repository.dart';
import '../../application/repositories/manual_override_repository.dart';
import '../../application/repositories/media_asset_repository.dart';
import '../../application/services/folder_mapping_service.dart';
import '../../application/services/manual_recategorization_service.dart';
import '../../domain/entities/manual_override.dart';
import '../repositories/local_classification_repository.dart';
import '../repositories/local_folder_cell_repository.dart';
import '../repositories/local_manual_override_repository.dart';
import '../repositories/local_media_asset_repository.dart';
import 'keyword_folder_mapping_service.dart';
import 'local_scan_result_store.dart';

class PersistedManualRecategorizationService
    implements ManualRecategorizationService {
  PersistedManualRecategorizationService({
    required ManualOverrideRepository manualOverrideRepository,
    required MediaAssetRepository mediaAssetRepository,
    required ClassificationRepository classificationRepository,
    required FolderCellRepository folderCellRepository,
    required FolderMappingService folderMappingService,
    DateTime Function()? now,
  }) : _manualOverrideRepository = manualOverrideRepository,
       _mediaAssetRepository = mediaAssetRepository,
       _classificationRepository = classificationRepository,
       _folderCellRepository = folderCellRepository,
       _folderMappingService = folderMappingService,
       _now = now ?? DateTime.now;

  final ManualOverrideRepository _manualOverrideRepository;
  final MediaAssetRepository _mediaAssetRepository;
  final ClassificationRepository _classificationRepository;
  final FolderCellRepository _folderCellRepository;
  final FolderMappingService _folderMappingService;
  final DateTime Function() _now;

  factory PersistedManualRecategorizationService.standard() {
    final store = LocalScanResultStore();
    return PersistedManualRecategorizationService(
      manualOverrideRepository: LocalManualOverrideRepository(store: store),
      mediaAssetRepository: LocalMediaAssetRepository(store: store),
      classificationRepository: LocalClassificationRepository(store: store),
      folderCellRepository: LocalFolderCellRepository(store: store),
      folderMappingService: KeywordFolderMappingService(),
    );
  }

  @override
  List<HiveCellCategory> get availableTargetCells => hiveTopLevelCategories;

  @override
  Future<void> moveAssetToCell({
    required String assetId,
    required String targetCellId,
  }) async {
    await _manualOverrideRepository.saveOverride(
      ManualOverride(
        id: 'manual_${assetId}_$targetCellId',
        assetId: assetId,
        action: ManualOverrideAction.includeInCell,
        createdAt: _now(),
        cellId: targetCellId,
        note: 'manual_move',
      ),
    );

    final assets = await _mediaAssetRepository.getAllAssets();
    final labelsByAssetId = await _classificationRepository.getLabelsForAssetIds(
      assets.map((asset) => asset.id).toList(growable: false),
    );
    final overrides = await _manualOverrideRepository.getAllOverrides();
    final cells = await _folderMappingService.buildSuggestedCells(
      assets: assets,
      labelsByAssetId: labelsByAssetId,
      overrides: overrides,
    );

    await _folderCellRepository.clear();
    await _folderCellRepository.saveCells(cells);
  }
}
