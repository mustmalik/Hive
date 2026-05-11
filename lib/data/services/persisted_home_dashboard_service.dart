import '../../application/models/home_cell_preview.dart';
import '../../application/models/home_dashboard_snapshot.dart';
import '../../application/repositories/classification_repository.dart';
import '../../application/repositories/folder_cell_repository.dart';
import '../../application/repositories/manual_override_repository.dart';
import '../../application/repositories/media_asset_repository.dart';
import '../../application/repositories/placement_audit_repository.dart';
import '../../application/repositories/scan_run_repository.dart';
import '../../application/services/folder_mapping_service.dart';
import '../../application/services/home_dashboard_service.dart';
import '../../application/services/media_library_service.dart';
import '../repositories/local_classification_repository.dart';
import '../repositories/local_folder_cell_repository.dart';
import '../repositories/local_manual_override_repository.dart';
import '../repositories/local_media_asset_repository.dart';
import '../repositories/local_placement_audit_repository.dart';
import '../repositories/local_scan_run_repository.dart';
import 'keyword_folder_mapping_service.dart';
import 'local_scan_result_store.dart';
import 'photo_manager_media_library_service.dart';
import 'placement/placement_definitions.dart';
import 'resolved_cell_membership.dart';
import 'result_pipeline_debug.dart';

class PersistedHomeDashboardService implements HomeDashboardService {
  PersistedHomeDashboardService({
    required MediaAssetRepository mediaAssetRepository,
    required FolderCellRepository folderCellRepository,
    required ClassificationRepository classificationRepository,
    required ManualOverrideRepository manualOverrideRepository,
    required FolderMappingService folderMappingService,
    required ScanRunRepository scanRunRepository,
    required PlacementAuditRepository placementAuditRepository,
    MediaLibraryService? mediaLibraryService,
  }) : _mediaAssetRepository = mediaAssetRepository,
       _folderCellRepository = folderCellRepository,
       _classificationRepository = classificationRepository,
       _manualOverrideRepository = manualOverrideRepository,
       _folderMappingService = folderMappingService,
       _scanRunRepository = scanRunRepository,
       _placementAuditRepository = placementAuditRepository,
       _mediaLibraryService = mediaLibraryService;

  final MediaAssetRepository _mediaAssetRepository;
  final FolderCellRepository _folderCellRepository;
  final ClassificationRepository _classificationRepository;
  final ManualOverrideRepository _manualOverrideRepository;
  final FolderMappingService _folderMappingService;
  final ScanRunRepository _scanRunRepository;
  final PlacementAuditRepository _placementAuditRepository;
  final MediaLibraryService? _mediaLibraryService;

  factory PersistedHomeDashboardService.standard() {
    final store = LocalScanResultStore();

    return PersistedHomeDashboardService(
      mediaAssetRepository: LocalMediaAssetRepository(store: store),
      folderCellRepository: LocalFolderCellRepository(store: store),
      classificationRepository: LocalClassificationRepository(store: store),
      manualOverrideRepository: LocalManualOverrideRepository(store: store),
      folderMappingService: KeywordFolderMappingService(),
      scanRunRepository: LocalScanRunRepository(store: store),
      placementAuditRepository: LocalPlacementAuditRepository(store: store),
      mediaLibraryService: const PhotoManagerMediaLibraryService(),
    );
  }

  static const Map<String, ({String summary, String styleKey, bool featured})>
  _previewContent = {
    'People': (
      summary: 'Portraits, selfies, and shared moments',
      styleKey: 'people',
      featured: true,
    ),
    'Family': (
      summary: 'The people you return to most',
      styleKey: 'family',
      featured: true,
    ),
    'Pets': (
      summary: 'Warm moments and familiar faces',
      styleKey: 'pets',
      featured: true,
    ),
    'Travel': (
      summary: 'Trips, weekends, and new places',
      styleKey: 'travel',
      featured: false,
    ),
    'Places': (
      summary: 'Scenery, venues, skylines, and memorable locations',
      styleKey: 'places',
      featured: false,
    ),
    'Food': (summary: 'Plates worth saving', styleKey: 'food', featured: false),
    'Videos': (
      summary: 'Clips, motion moments, and moving memories',
      styleKey: 'videos',
      featured: false,
    ),
    'Screenshots': (
      summary: 'Captured references and saved screens',
      styleKey: 'screenshots',
      featured: false,
    ),
    'Devices / Tech': (
      summary: 'Screens, devices, and tech hardware',
      styleKey: 'tech',
      featured: false,
    ),
    'Documents / Receipts': (
      summary: 'Paperwork and references worth keeping',
      styleKey: 'documents',
      featured: false,
    ),
    'Sports': (
      summary: 'Games, training, and courtside energy',
      styleKey: 'sports',
      featured: true,
    ),
    'Animation': (
      summary: 'Anime, manga, cartoons, comics, and stylized art',
      styleKey: 'animation',
      featured: true,
    ),
    'Memes': (
      summary: 'Jokes, edits, overlays, and internet commentary',
      styleKey: 'memes',
      featured: true,
    ),
    'Unsorted': (
      summary: 'The next clean-up pass',
      styleKey: 'unsorted',
      featured: false,
    ),
  };

  @override
  Future<HomeDashboardSnapshot> loadDashboard() async {
    final cells = await _folderCellRepository.getAllCells();
    final assets = await _mediaAssetRepository.getAllAssets();
    final assetIds = assets.map((asset) => asset.id).toList(growable: false);
    final labelsByAssetId = await _classificationRepository
        .getLabelsForAssetIds(assetIds);
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
    final resolvedAssetIdsByCellId = <String, Set<String>>{};
    final resolvedCellIdsByAssetId = <String, String>{};
    for (final asset in assets) {
      final override = manualOverrides[asset.id];
      final resolvedCellId =
          override?.cellId ??
          auditedFinalCellByAssetId[asset.id] ??
          resolveCellIdForAsset(
            asset: asset,
            labels: labelsByAssetId[asset.id] ?? const [],
            folderMappingService: _folderMappingService,
            override: null,
          );
      resolvedCellIdsByAssetId[asset.id] = resolvedCellId;
      resolvedAssetIdsByCellId
          .putIfAbsent(resolvedCellId, () => <String>{})
          .add(asset.id);
      debugResultsLog('dashboard resolved final asset=${asset.id} cell=$resolvedCellId');
    }
    final latestRun = await _scanRunRepository.getLatestRun();
    final totalAssetCount = await _resolveTotalAssetCount(
      fallbackCount: assets.length,
    );
    final cellIdsToRender = _mergePersistedAndResolvedCellIds(
      persistedCellIds: cells.map((cell) => cell.id),
      resolvedCellIds: resolvedAssetIdsByCellId.keys,
    );
    if (cellIdsToRender.isEmpty) {
      if (latestRun == null) {
        return HomeDashboardSnapshot(
          totalAssetCount: totalAssetCount,
          totalCellCount: 0,
          lastCompletedScanAt: null,
          visibleCells: const [],
          hasCompletedScan: false,
          meaningfulCellCount: 0,
        );
      }

      return HomeDashboardSnapshot(
        totalAssetCount: totalAssetCount,
        totalCellCount: 0,
        lastCompletedScanAt: latestRun.completedAt,
        visibleCells: const [],
        hasCompletedScan: latestRun.completedAt != null,
        meaningfulCellCount: 0,
      );
    }

    final visibleCells = <HomeCellPreview>[];
    var meaningfulCellCount = 0;
    final persistedCellsById = {for (final cell in cells) cell.id: cell};

    for (final cellId in cellIdsToRender) {
      final cell = persistedCellsById[cellId];
      final cellName = cell?.name ?? _cellNameForId(cellId);
      final preview = _previewForCell(
        cellId: cellId,
        cellName: cellName,
        description: cell?.description,
      );
      final resolvedAssetCount = resolvedAssetIdsByCellId[cellId]?.length ?? 0;

      visibleCells.add(
        HomeCellPreview(
          id: cellId,
          name: cellName,
          assetCount: resolvedAssetCount,
          summary: preview.summary,
          styleKey: preview.styleKey,
          featured: preview.featured,
        ),
      );

      if (resolvedAssetCount > 0 && cellName != 'Unsorted') {
        meaningfulCellCount += 1;
      }
    }

    final renderedAssetIds = <String>{
      for (final cell in visibleCells)
        ...(resolvedAssetIdsByCellId[cell.id] ?? const <String>{}),
    };
    final persistedGroupedAssetIds = uniqueAssetIdsInCells(cells);
    final missingPersistedGroupedIds = missingIds(
      expected: assetIds,
      actual: persistedGroupedAssetIds,
    );
    final missingRenderedIds = missingIds(
      expected: assetIds,
      actual: renderedAssetIds,
    );
    debugResultsLog(
      'dashboard reload persistedAssets=${assetIds.length} '
      'classified=${labelsByAssetId.length} persistedCells=${cells.length} '
      'renderedCells=${visibleCells.length} persistedGrouped='
      '${persistedGroupedAssetIds.length} renderedAssets='
      '${renderedAssetIds.length} assetIds=${debugIdSet(assetIds)} '
      'persistedGroupedIds=${debugIdSet(persistedGroupedAssetIds)} '
      'renderedIds=${debugIdSet(renderedAssetIds)} '
      'resolvedByCell=${debugCellAssetMap(resolvedAssetIdsByCellId)}',
    );
    if (missingPersistedGroupedIds.isNotEmpty) {
      debugResultsLog(
        'dashboard missing from persisted cells='
        '${debugIdSet(missingPersistedGroupedIds)} '
        'finalKnownPlacement=$resolvedCellIdsByAssetId',
      );
    }
    if (missingRenderedIds.isNotEmpty) {
      debugResultsLog(
        'dashboard missing rendered=${debugIdSet(missingRenderedIds)} '
        'finalKnownPlacement=$resolvedCellIdsByAssetId',
      );
    }

    return HomeDashboardSnapshot(
      totalAssetCount: totalAssetCount,
      totalCellCount: visibleCells.length,
      lastCompletedScanAt: latestRun?.completedAt,
      visibleCells: visibleCells,
      hasCompletedScan: latestRun?.completedAt != null,
      meaningfulCellCount: meaningfulCellCount,
    );
  }

  Future<int> _resolveTotalAssetCount({required int fallbackCount}) async {
    final mediaLibraryService = _mediaLibraryService;
    if (mediaLibraryService == null) {
      return fallbackCount;
    }

    try {
      final count = await mediaLibraryService.getEstimatedAssetCount();
      return count > 0 ? count : fallbackCount;
    } catch (_) {
      return fallbackCount;
    }
  }

  List<String> _mergePersistedAndResolvedCellIds({
    required Iterable<String> persistedCellIds,
    required Iterable<String> resolvedCellIds,
  }) {
    final result = <String>[];
    final seen = <String>{};

    for (final cellId in persistedCellIds) {
      if (seen.add(cellId)) {
        result.add(cellId);
      }
    }

    final canonicalCellIds = [
      for (final rule in KeywordPlacementDefinitions.rules) rule.cellId,
      KeywordPlacementDefinitions.unsortedRule.cellId,
    ];
    final missingResolvedCellIds = resolvedCellIds
        .where((cellId) => !seen.contains(cellId))
        .toSet();
    for (final cellId in canonicalCellIds) {
      if (missingResolvedCellIds.remove(cellId) && seen.add(cellId)) {
        result.add(cellId);
      }
    }
    for (final cellId in missingResolvedCellIds.toList(
      growable: false,
    )..sort()) {
      if (seen.add(cellId)) {
        result.add(cellId);
      }
    }

    return result;
  }

  ({String summary, String styleKey, bool featured}) _previewForCell({
    required String cellId,
    required String cellName,
    String? description,
  }) {
    final existing = _previewContent[cellName];
    if (existing != null) {
      return existing;
    }

    final rule = KeywordPlacementDefinitions.ruleForCellId(cellId);
    if (rule != null) {
      return (
        summary: description ?? rule.description,
        styleKey: rule.styleKey,
        featured: rule.featured,
      );
    }

    return (
      summary: description ?? 'A local HIVE cell',
      styleKey: 'unsorted',
      featured: false,
    );
  }

  String _cellNameForId(String cellId) {
    final rule = KeywordPlacementDefinitions.ruleForCellId(cellId);
    if (rule != null) {
      return rule.cellName;
    }

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
