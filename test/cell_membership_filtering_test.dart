import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter_v1/application/models/asset_mapping_explanation.dart';
import 'package:hive_flutter_v1/data/repositories/in_memory_classification_repository.dart';
import 'package:hive_flutter_v1/data/repositories/in_memory_folder_cell_repository.dart';
import 'package:hive_flutter_v1/data/repositories/in_memory_manual_override_repository.dart';
import 'package:hive_flutter_v1/data/repositories/in_memory_media_asset_repository.dart';
import 'package:hive_flutter_v1/data/repositories/in_memory_placement_audit_repository.dart';
import 'package:hive_flutter_v1/data/repositories/in_memory_scan_run_repository.dart';
import 'package:hive_flutter_v1/data/services/persisted_folder_detail_service.dart';
import 'package:hive_flutter_v1/data/services/persisted_home_dashboard_service.dart';
import 'package:hive_flutter_v1/domain/entities/classification_label.dart';
import 'package:hive_flutter_v1/domain/entities/folder_cell.dart';
import 'package:hive_flutter_v1/domain/entities/manual_override.dart';
import 'package:hive_flutter_v1/domain/entities/media_asset.dart';
import 'package:hive_flutter_v1/application/services/folder_mapping_service.dart';
import 'package:hive_flutter_v1/domain/entities/scan_run.dart';

void main() {
  test(
    'folder detail only returns assets whose resolved cellId matches the selected cell',
    () async {
      final documentsAsset = _asset('asset_document', 'receipt.jpg');
      final peopleAsset = _asset('asset_people', 'portrait.jpg');
      final screenshotsAsset = _asset('asset_screenshot', 'capture.png');
      final folderCellRepository = InMemoryFolderCellRepository(
        seedCells: [
          FolderCell(
            id: 'documents_receipts',
            name: 'Documents / Receipts',
            origin: FolderCellOrigin.suggested,
            createdAt: DateTime(2026, 4, 28),
            updatedAt: DateTime(2026, 4, 28),
            assetIds: [documentsAsset.id, peopleAsset.id, screenshotsAsset.id],
          ),
        ],
      );
      final mediaAssetRepository = InMemoryMediaAssetRepository(
        seedAssets: [documentsAsset, peopleAsset, screenshotsAsset],
      );
      final classificationRepository = InMemoryClassificationRepository(
        seedLabels: {
          documentsAsset.id: [_label('receipt')],
          peopleAsset.id: [_label('person')],
          screenshotsAsset.id: [_label('user interface')],
        },
      );
      final service = PersistedFolderDetailService(
        folderCellRepository: folderCellRepository,
        mediaAssetRepository: mediaAssetRepository,
        classificationRepository: classificationRepository,
        manualOverrideRepository: InMemoryManualOverrideRepository(),
        folderMappingService: _FakeFolderMappingService(
          explanationsByAssetId: {
            documentsAsset.id: _explanation(
              cellId: 'documents_receipts',
              cellName: 'Documents / Receipts',
            ),
            peopleAsset.id: _explanation(cellId: 'people', cellName: 'People'),
            screenshotsAsset.id: _explanation(
              cellId: 'screenshots',
              cellName: 'Screenshots',
            ),
          },
        ),
        placementAuditRepository: InMemoryPlacementAuditRepository(),
      );

      final snapshot = await service.loadCell('documents_receipts');

      expect(snapshot, isNotNull);
      expect(snapshot!.cellId, 'documents_receipts');
      expect(snapshot.totalCount, 1);
      expect(snapshot.items, hasLength(1));
      expect(snapshot.items.single.asset.id, documentsAsset.id);
      expect(
        snapshot.items.single.mappingExplanation?.cellId,
        'documents_receipts',
      );
    },
  );

  test(
    'home dashboard member counts use resolved cellId matches instead of stored assetIds length',
    () async {
      final documentsAsset = _asset('asset_document', 'receipt.jpg');
      final peopleAsset = _asset('asset_people', 'portrait.jpg');
      final screenshotsAsset = _asset('asset_screenshot', 'capture.png');
      final allAssetIds = [
        documentsAsset.id,
        peopleAsset.id,
        screenshotsAsset.id,
      ];
      final folderCellRepository = InMemoryFolderCellRepository(
        seedCells: [
          FolderCell(
            id: 'documents_receipts',
            name: 'Documents / Receipts',
            origin: FolderCellOrigin.suggested,
            createdAt: DateTime(2026, 4, 28),
            updatedAt: DateTime(2026, 4, 28),
            assetIds: allAssetIds,
          ),
          FolderCell(
            id: 'people',
            name: 'People',
            origin: FolderCellOrigin.suggested,
            createdAt: DateTime(2026, 4, 28),
            updatedAt: DateTime(2026, 4, 28),
            assetIds: allAssetIds,
          ),
          FolderCell(
            id: 'screenshots',
            name: 'Screenshots',
            origin: FolderCellOrigin.suggested,
            createdAt: DateTime(2026, 4, 28),
            updatedAt: DateTime(2026, 4, 28),
            assetIds: allAssetIds,
          ),
        ],
      );
      final mediaAssetRepository = InMemoryMediaAssetRepository(
        seedAssets: [documentsAsset, peopleAsset, screenshotsAsset],
      );
      final classificationRepository = InMemoryClassificationRepository(
        seedLabels: {
          documentsAsset.id: [_label('receipt')],
          peopleAsset.id: [_label('person')],
          screenshotsAsset.id: [_label('user interface')],
        },
      );
      final service = PersistedHomeDashboardService(
        mediaAssetRepository: mediaAssetRepository,
        folderCellRepository: folderCellRepository,
        classificationRepository: classificationRepository,
        manualOverrideRepository: InMemoryManualOverrideRepository(),
        folderMappingService: _FakeFolderMappingService(
          explanationsByAssetId: {
            documentsAsset.id: _explanation(
              cellId: 'documents_receipts',
              cellName: 'Documents / Receipts',
            ),
            peopleAsset.id: _explanation(cellId: 'people', cellName: 'People'),
            screenshotsAsset.id: _explanation(
              cellId: 'screenshots',
              cellName: 'Screenshots',
            ),
          },
        ),
        scanRunRepository: InMemoryScanRunRepository(seedRuns: const []),
        placementAuditRepository: InMemoryPlacementAuditRepository(),
      );

      final dashboard = await service.loadDashboard();

      final documentsPreview = dashboard.visibleCells.firstWhere(
        (cell) => cell.id == 'documents_receipts',
      );
      final peoplePreview = dashboard.visibleCells.firstWhere(
        (cell) => cell.id == 'people',
      );
      final screenshotsPreview = dashboard.visibleCells.firstWhere(
        (cell) => cell.id == 'screenshots',
      );

      expect(documentsPreview.assetCount, 1);
      expect(peoplePreview.assetCount, 1);
      expect(screenshotsPreview.assetCount, 1);
    },
  );

  test(
    'post-scan refresh preserves every asset when a resolved single-item cell is missing from persisted cells',
    () async {
      final assets = List<MediaAsset>.generate(
        18,
        (index) => _asset('asset_$index', 'IMG_$index.jpg'),
      );
      final memeAsset = assets.last;
      final explanationsByAssetId = <String, AssetMappingExplanation>{};
      final cellIds = <String>[
        'people',
        'places',
        'food',
        'screenshots',
        'documents_receipts',
        'sports',
        'pets',
      ];
      final cellNames = <String, String>{
        'people': 'People',
        'places': 'Places',
        'food': 'Food',
        'screenshots': 'Screenshots',
        'documents_receipts': 'Documents / Receipts',
        'sports': 'Sports',
        'pets': 'Pets',
        'animation': 'Animation',
        'memes': 'Memes',
      };

      for (var index = 0; index < assets.length - 1; index++) {
        final cellId = cellIds[index % cellIds.length];
        explanationsByAssetId[assets[index].id] = _explanation(
          cellId: cellId,
          cellName: cellNames[cellId]!,
        );
      }
      explanationsByAssetId[memeAsset.id] = _explanation(
        cellId: 'memes',
        cellName: 'Memes',
      );

      final persistedCells = <FolderCell>[
        for (final cellId in cellIds)
          FolderCell(
            id: cellId,
            name: cellNames[cellId]!,
            origin: FolderCellOrigin.suggested,
            createdAt: DateTime(2026, 4, 28),
            updatedAt: DateTime(2026, 4, 28),
            assetIds: [
              for (var index = 0; index < assets.length - 1; index++)
                if (cellIds[index % cellIds.length] == cellId) assets[index].id,
            ],
          ),
      ];
      final folderCellRepository = InMemoryFolderCellRepository(
        seedCells: persistedCells,
      );
      final mediaAssetRepository = InMemoryMediaAssetRepository(
        seedAssets: assets,
      );
      final classificationRepository = InMemoryClassificationRepository(
        seedLabels: {
          for (final asset in assets)
            asset.id: asset == memeAsset
                ? [_label('art'), _label('illustrations')]
                : [_label('person')],
        },
      );
      final mappingService = _FakeFolderMappingService(
        explanationsByAssetId: explanationsByAssetId,
      );
      final scanRunRepository = InMemoryScanRunRepository(
        seedRuns: [
          ScanRun(
            id: 'scan_refresh_1',
            status: ScanRunStatus.completed,
            startedAt: DateTime(2026, 4, 28, 12),
            completedAt: DateTime(2026, 4, 28, 12, 1),
            discoveredAssetCount: 18,
            classifiedAssetCount: 18,
            generatedCellCount: persistedCells.length,
          ),
        ],
      );
      final dashboardService = PersistedHomeDashboardService(
        mediaAssetRepository: mediaAssetRepository,
        folderCellRepository: folderCellRepository,
        classificationRepository: classificationRepository,
        manualOverrideRepository: InMemoryManualOverrideRepository(),
        folderMappingService: mappingService,
        scanRunRepository: scanRunRepository,
        placementAuditRepository: InMemoryPlacementAuditRepository(),
      );
      final folderDetailService = PersistedFolderDetailService(
        folderCellRepository: folderCellRepository,
        mediaAssetRepository: mediaAssetRepository,
        classificationRepository: classificationRepository,
        manualOverrideRepository: InMemoryManualOverrideRepository(),
        folderMappingService: mappingService,
        placementAuditRepository: InMemoryPlacementAuditRepository(),
      );

      final firstDashboard = await dashboardService.loadDashboard();
      final refreshedDashboard = await dashboardService.loadDashboard();
      final animationPreview = refreshedDashboard.visibleCells.firstWhere(
        (cell) => cell.id == 'memes',
      );

      expect(firstDashboard.visibleCells.length, persistedCells.length + 1);
      expect(refreshedDashboard.visibleCells.length, persistedCells.length + 1);
      expect(animationPreview.assetCount, 1);

      final renderedIds = <String>{};
      var renderedCount = 0;
      for (final cell in refreshedDashboard.visibleCells) {
        final snapshot = await folderDetailService.loadCell(cell.id);
        expect(snapshot, isNotNull);
        renderedCount += snapshot!.items.length;
        renderedIds.addAll(snapshot.items.map((item) => item.asset.id));
      }

      expect(renderedCount, 18);
      expect(renderedIds, hasLength(18));
      expect(renderedIds, contains(memeAsset.id));

      final animationSnapshot = await folderDetailService.loadCell(
        'memes',
      );
      expect(animationSnapshot, isNotNull);
      expect(animationSnapshot!.items, hasLength(1));
      expect(animationSnapshot.items.single.asset.id, memeAsset.id);
    },
  );
}

class _FakeFolderMappingService implements FolderMappingService {
  _FakeFolderMappingService({required this.explanationsByAssetId});

  final Map<String, AssetMappingExplanation> explanationsByAssetId;

  @override
  Future<List<FolderCell>> buildSuggestedCells({
    required List<MediaAsset> assets,
    required Map<String, List<ClassificationLabel>> labelsByAssetId,
    List<ManualOverride> overrides = const [],
  }) async {
    return const [];
  }

  @override
  AssetMappingExplanation explainPlacement({
    required MediaAsset asset,
    required List<ClassificationLabel> labels,
  }) {
    return explanationsByAssetId[asset.id]!;
  }
}

MediaAsset _asset(String id, String filename) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    createdAt: DateTime(2026, 4, 28),
    modifiedAt: DateTime(2026, 4, 28),
    width: 1200,
    height: 1600,
    originalFilename: filename,
  );
}

ClassificationLabel _label(String name) {
  return ClassificationLabel(
    id: name,
    key: name,
    displayName: name,
    confidence: 0.9,
    source: ClassificationLabelSource.onDeviceModel,
    createdAt: DateTime(2026, 4, 28),
    modelIdentifier: 'test',
  );
}

AssetMappingExplanation _explanation({
  required String cellId,
  required String cellName,
}) {
  return AssetMappingExplanation(
    cellId: cellId,
    cellName: cellName,
    score: 0.9,
    usedFallback: false,
    topLabels: const [],
    matchedKeywords: const ['test'],
  );
}
