import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter_v1/application/models/placement_audit_entry.dart';
import 'package:hive_flutter_v1/data/repositories/local_classification_repository.dart';
import 'package:hive_flutter_v1/data/repositories/local_folder_cell_repository.dart';
import 'package:hive_flutter_v1/data/repositories/local_manual_override_repository.dart';
import 'package:hive_flutter_v1/data/repositories/local_media_asset_repository.dart';
import 'package:hive_flutter_v1/data/repositories/local_placement_audit_repository.dart';
import 'package:hive_flutter_v1/data/repositories/local_scan_run_repository.dart';
import 'package:hive_flutter_v1/data/services/keyword_folder_mapping_service.dart';
import 'package:hive_flutter_v1/data/services/local_scan_result_store.dart';
import 'package:hive_flutter_v1/data/services/persisted_folder_detail_service.dart';
import 'package:hive_flutter_v1/data/services/persisted_home_dashboard_service.dart';
import 'package:hive_flutter_v1/data/services/placement/keyword_placement_pipeline.dart';
import 'package:hive_flutter_v1/data/services/structural_signal_extractor.dart';
import 'package:hive_flutter_v1/domain/entities/classification_label.dart';
import 'package:hive_flutter_v1/domain/entities/folder_cell.dart';
import 'package:hive_flutter_v1/domain/entities/media_asset.dart';

void main() {
  test(
    'dashboard/folder detail prefer final audited cell over stale persisted membership',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('hive_scan_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final store = LocalScanResultStore(
        directoryProvider: () async => tempDir,
        fileName: 'scan_results_test.json',
      );
      final mediaRepo = LocalMediaAssetRepository(store: store);
      final cellRepo = LocalFolderCellRepository(store: store);
      final classificationRepo = LocalClassificationRepository(store: store);
      final overrideRepo = LocalManualOverrideRepository(store: store);
      final runRepo = LocalScanRunRepository(store: store);
      final auditRepo = LocalPlacementAuditRepository(store: store);

      final asset = MediaAsset(
        id: 'asset_quote_card_1',
        type: MediaAssetType.image,
        createdAt: DateTime(2026, 5, 1),
        modifiedAt: DateTime(2026, 5, 1),
        width: 1200,
        height: 1600,
        originalFilename: 'IMG_0001.JPG',
      );
      await mediaRepo.replaceAll([asset]);
      await overrideRepo.clear();

      final labels = [
        _label('person', 0.88),
        _label('adult', 0.86),
        _label('athlete', 0.84),
        _label('jersey', 0.82),
      ];
      await classificationRepo.saveLabelsForAsset(asset.id, labels);

      // Provisional (sync) placement should be People because structural signals are empty.
      final pipeline = KeywordPlacementPipeline(
        analysisBuilder: PlacementAnalysisBuilder(
          structuralExtractor: StructuralSignalExtractor(
            imageLoader: (asset) => _fakeStructuralImageLoader(asset, tempDir),
            faceExtractor: (_) async => const StructuralFaceObservation(
              faceCount: 1,
              largestFaceAreaRatio: 0.25,
            ),
            textExtractor: (_) async => const StructuralTextObservation(
              lineTexts: [
                'HE SAID',
                'WE WILL WIN',
                'BEFORE',
                'THE GAME',
                'TODAY',
              ],
              blockCount: 2,
              textCoverageRatio: 0.35,
            ),
            barcodeExtractor: (_) async => StructuralBarcodeObservation.empty,
          ),
        ),
      );
      final mappingService = KeywordFolderMappingService(pipeline: pipeline);
      final provisional = mappingService.explainPlacement(asset: asset, labels: labels);
      expect(provisional.cellId, 'people');

      // Persist a stale membership under People (simulating contamination).
      // The authoritative final placement is stored in the audit log as meme.
      final now = DateTime(2026, 5, 1, 10, 0, 0);
      await cellRepo.replaceAll(
        [
          FolderCell(
            id: 'people',
            name: 'People',
            origin: FolderCellOrigin.suggested,
            createdAt: now,
            updatedAt: now,
            assetIds: const ['asset_quote_card_1'],
            isPinned: true,
          ),
          FolderCell(
            id: 'memes',
            name: 'Memes',
            origin: FolderCellOrigin.suggested,
            createdAt: now,
            updatedAt: now,
            assetIds: const [],
            isPinned: true,
          ),
        ],
      );
      await auditRepo.saveEntry(
        PlacementAuditEntry(
          assetId: asset.id,
          finalCell: 'memes',
          routeLayer: 'final_persist',
          topScores: const {},
          firedVetoes: const [],
          firedGates: const [],
          isNaturalPhoto: false,
          humanPresenceScore: 0,
          animalPresenceScore: 0,
          graphicnessScore: 0,
          documentnessScore: 0,
          sceneDensityScore: 0,
          timestamp: now,
        ),
      );

      final dashboard = PersistedHomeDashboardService(
        mediaAssetRepository: mediaRepo,
        folderCellRepository: cellRepo,
        classificationRepository: classificationRepo,
        manualOverrideRepository: overrideRepo,
        folderMappingService: mappingService,
        scanRunRepository: runRepo,
        placementAuditRepository: auditRepo,
      );

      final snapshot = await dashboard.loadDashboard();
      final peoplePreview = snapshot.visibleCells.firstWhere(
        (cell) => cell.id == 'people',
      );
      final memePreview = snapshot.visibleCells.firstWhere(
        (cell) => cell.id == 'memes',
      );
      expect(peoplePreview.assetCount, 0);
      expect(memePreview.assetCount, 1);

      final folderDetail = PersistedFolderDetailService(
        folderCellRepository: cellRepo,
        mediaAssetRepository: mediaRepo,
        classificationRepository: classificationRepo,
        manualOverrideRepository: overrideRepo,
        folderMappingService: mappingService,
        placementAuditRepository: auditRepo,
      );

      final peopleDetail = await folderDetail.loadCell('people');
      expect(peopleDetail, isNotNull);
      expect(
        peopleDetail!.items.map((i) => i.asset.id),
        isNot(contains(asset.id)),
      );

      final memeDetail = await folderDetail.loadCell('memes');
      expect(memeDetail, isNotNull);
      expect(memeDetail!.items.map((i) => i.asset.id), contains(asset.id));
    },
  );
}

ClassificationLabel _label(String name, double confidence) {
  final createdAt = DateTime(2026, 5, 1);
  return ClassificationLabel(
    id: name.toLowerCase(),
    key: name.toLowerCase(),
    displayName: name,
    confidence: confidence,
    source: ClassificationLabelSource.onDeviceModel,
    createdAt: createdAt,
    modelIdentifier: 'test',
  );
}

Future<StructuralSourceImage?> _fakeStructuralImageLoader(
  MediaAsset asset,
  Directory tempDir,
) async {
  final path = '${tempDir.path}/${asset.id}.jpg';
  final file = File(path);
  if (!await file.exists()) {
    await file.writeAsBytes(<int>[1, 2, 3], flush: true);
  }
  return StructuralSourceImage(
    filePath: path,
    imageWidth: asset.width,
    imageHeight: asset.height,
  );
}

