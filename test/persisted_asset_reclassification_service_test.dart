import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter_v1/application/models/classification_outcome.dart';
import 'package:hive_flutter_v1/application/services/classification_service.dart';
import 'package:hive_flutter_v1/data/repositories/in_memory_classification_repository.dart';
import 'package:hive_flutter_v1/data/repositories/in_memory_folder_cell_repository.dart';
import 'package:hive_flutter_v1/data/repositories/in_memory_manual_override_repository.dart';
import 'package:hive_flutter_v1/data/repositories/in_memory_media_asset_repository.dart';
import 'package:hive_flutter_v1/data/services/keyword_folder_mapping_service.dart';
import 'package:hive_flutter_v1/data/services/persisted_asset_reclassification_service.dart';
import 'package:hive_flutter_v1/domain/entities/classification_label.dart';
import 'package:hive_flutter_v1/domain/entities/media_asset.dart';

void main() {
  test(
    'reclassifyAsset refreshes one asset outcome and rebuilds saved cells',
    () async {
      final asset = MediaAsset(
        id: 'asset_1',
        type: MediaAssetType.image,
        createdAt: DateTime(2026, 4, 20, 12),
        modifiedAt: DateTime(2026, 4, 20, 12),
        width: 1200,
        height: 1600,
        originalFilename: 'receipt_scan.jpg',
      );
      final initialOutcome = ClassificationOutcome(
        assetId: asset.id,
        status: ClassificationOutcomeStatus.succeeded,
        labels: [_label('person', 0.91)],
        classificationRan: true,
        imagePreparationSucceeded: true,
        noLabelsReturned: false,
      );
      final classificationRepository = InMemoryClassificationRepository(
        seedOutcomes: {asset.id: initialOutcome},
      );
      final mediaAssetRepository = InMemoryMediaAssetRepository(
        seedAssets: [asset],
      );
      final folderMappingService = KeywordFolderMappingService();
      final initialCells = await folderMappingService.buildSuggestedCells(
        assets: [asset],
        labelsByAssetId: {asset.id: initialOutcome.labels},
      );
      final folderCellRepository = InMemoryFolderCellRepository(
        seedCells: initialCells,
      );
      final service = PersistedAssetReclassificationService(
        classificationService: _FakeClassificationService(
          outcomesByAssetId: {
            asset.id: ClassificationOutcome(
              assetId: asset.id,
              status: ClassificationOutcomeStatus.succeeded,
              labels: [
                _label('document', 0.92),
                _label('receipt', 0.88),
                _label('text', 0.74),
              ],
              classificationRan: true,
              imagePreparationSucceeded: true,
              noLabelsReturned: false,
            ),
          },
        ),
        classificationRepository: classificationRepository,
        mediaAssetRepository: mediaAssetRepository,
        folderCellRepository: folderCellRepository,
        manualOverrideRepository: InMemoryManualOverrideRepository(),
        folderMappingService: folderMappingService,
      );

      final item = await service.reclassifyAsset(assetId: asset.id);

      expect(item, isNotNull);
      expect(item!.mappingExplanation?.cellId, 'documents_receipts');

      final refreshedOutcome = (await classificationRepository
          .getOutcomesForAssetIds([asset.id]))[asset.id];
      expect(refreshedOutcome, isNotNull);
      expect(refreshedOutcome!.labels.first.displayName, 'document');

      final savedCells = await folderCellRepository.getAllCells();
      final documentsCell = savedCells.singleWhere(
        (cell) => cell.id == 'documents_receipts',
      );
      expect(documentsCell.assetIds, contains(asset.id));
      expect(savedCells.where((cell) => cell.id == 'people'), isEmpty);
    },
  );
}

ClassificationLabel _label(String name, double confidence) {
  return ClassificationLabel(
    id: name,
    key: name,
    displayName: name,
    confidence: confidence,
    source: ClassificationLabelSource.onDeviceModel,
    createdAt: DateTime(2026, 4, 20, 12),
    modelIdentifier: 'test',
  );
}

class _FakeClassificationService extends ClassificationService {
  _FakeClassificationService({required this.outcomesByAssetId});

  final Map<String, ClassificationOutcome> outcomesByAssetId;

  @override
  Future<ClassificationOutcome> classifyAssetDetailed(MediaAsset asset) async {
    return outcomesByAssetId[asset.id]!;
  }
}
