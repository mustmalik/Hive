import '../../application/models/asset_mapping_explanation.dart';
import '../../application/services/folder_mapping_service.dart';
import '../../domain/entities/classification_label.dart';
import '../../domain/entities/folder_cell.dart';
import '../../domain/entities/manual_override.dart';
import '../../domain/entities/media_asset.dart';
import 'placement/keyword_placement_pipeline.dart';
import 'result_pipeline_debug.dart';

class KeywordFolderMappingService implements FolderMappingService {
  KeywordFolderMappingService({
    DateTime Function()? now,
    KeywordPlacementPipeline? pipeline,
  }) : _now = now ?? DateTime.now,
       _pipeline = pipeline ?? KeywordPlacementPipeline();

  final DateTime Function() _now;
  final KeywordPlacementPipeline _pipeline;

  Future<void> primeStructuralSignals({required MediaAsset asset}) async {
    await _pipeline.primeStructuralSignals(asset: asset);
  }

  Future<AssetMappingExplanation> explainPlacementAsync({
    required MediaAsset asset,
    required List<ClassificationLabel> labels,
  }) {
    return _pipeline.explainPlacementAsync(asset: asset, labels: labels);
  }

  @override
  Future<List<FolderCell>> buildSuggestedCells({
    required List<MediaAsset> assets,
    required Map<String, List<ClassificationLabel>> labelsByAssetId,
    List<ManualOverride> overrides = const [],
  }) async {
    final now = _now();
    final includeOverridesByAssetId = _resolveIncludeOverrides(overrides);
    final assetsByCellId = <String, List<String>>{};
    final labelIdsByCellId = <String, Set<String>>{};
    final coverAssetIdByCellId = <String, String>{};
    final placementsByAssetId = <String, String>{};

    debugResultsLog(
      'mapping start scanned=${assets.length} '
      'assetIds=${debugIdSet(assets.map((asset) => asset.id))}',
    );

    for (final asset in assets) {
      final override = includeOverridesByAssetId[asset.id];
      final explanation = override == null
          ? await explainPlacementAsync(
              asset: asset,
              labels: labelsByAssetId[asset.id] ?? const [],
            )
          : _manualOverrideExplanation(
              asset: asset,
              cellId: override.cellId!,
              labels: labelsByAssetId[asset.id] ?? const [],
            );
      placementsByAssetId[asset.id] = explanation.cellId;

      debugResultsLog(
        'placed asset=${asset.id} finalCell=${explanation.cellId} '
        'cellName="${explanation.cellName}"',
      );

      assetsByCellId
          .putIfAbsent(explanation.cellId, () => <String>[])
          .add(asset.id);

      if (!coverAssetIdByCellId.containsKey(explanation.cellId)) {
        coverAssetIdByCellId[explanation.cellId] = asset.id;
      }

      final labelIds = labelIdsByCellId.putIfAbsent(
        explanation.cellId,
        () => <String>{},
      );
      for (final label
          in labelsByAssetId[asset.id] ?? const <ClassificationLabel>[]) {
        labelIds.add(label.id);
      }
    }

    final orderedRules = [
      ..._pipeline.rules.where(
        (rule) => assetsByCellId.containsKey(rule.cellId),
      ),
      if (assetsByCellId.containsKey(_pipeline.unsortedRule.cellId))
        _pipeline.unsortedRule,
    ];

    final cells = orderedRules
        .map(
          (rule) => FolderCell(
            id: rule.cellId,
            name: rule.cellName,
            origin: FolderCellOrigin.suggested,
            createdAt: now,
            updatedAt: now,
            description: rule.description,
            coverAssetId: coverAssetIdByCellId[rule.cellId],
            labelIds: (labelIdsByCellId[rule.cellId] ?? const <String>{})
                .toList(growable: false),
            assetIds: List<String>.unmodifiable(
              assetsByCellId[rule.cellId] ?? const <String>[],
            ),
            isPinned: rule.featured,
          ),
        )
        .toList(growable: false);

    final groupedIds = uniqueAssetIdsInCells(cells);
    final scannedIds = assets.map((asset) => asset.id).toSet();
    final missing = missingIds(expected: scannedIds, actual: groupedIds);
    final omittedUnknownCellIds = assetsByCellId.keys
        .where((cellId) => !cells.any((cell) => cell.id == cellId))
        .toSet();
    debugResultsLog(
      'mapping complete scanned=${scannedIds.length} '
      'placed=${placementsByAssetId.length} grouped=${groupedIds.length} '
      'cells=${cells.length} groupedByCell=${debugFolderCells(cells)}',
    );
    if (missing.isNotEmpty || omittedUnknownCellIds.isNotEmpty) {
      debugResultsLog(
        'missing after grouping=${debugIdSet(missing)} '
        'omittedCellIds=${debugIdSet(omittedUnknownCellIds)} '
        'placements=$placementsByAssetId',
      );
    }

    return cells;
  }

  Map<String, ManualOverride> _resolveIncludeOverrides(
    List<ManualOverride> overrides,
  ) {
    final result = <String, ManualOverride>{};

    for (final override in overrides) {
      if (override.action != ManualOverrideAction.includeInCell ||
          override.cellId == null) {
        continue;
      }

      final existing = result[override.assetId];
      if (existing == null || override.createdAt.isAfter(existing.createdAt)) {
        result[override.assetId] = override;
      }
    }

    return result;
  }

  AssetMappingExplanation _manualOverrideExplanation({
    required MediaAsset asset,
    required String cellId,
    required List<ClassificationLabel> labels,
  }) {
    final rule = _pipeline.ruleForCellId(cellId) ?? _pipeline.unsortedRule;
    final sortedLabels = List<ClassificationLabel>.from(labels)
      ..sort((left, right) => right.confidence.compareTo(left.confidence));

    return AssetMappingExplanation(
      cellId: rule.cellId,
      cellName: rule.cellName,
      score: 1.5,
      usedFallback: false,
      topLabels: sortedLabels
          .take(_pipeline.maxExplanationLabels)
          .toList(growable: false),
      matchedKeywords: const ['manual override'],
      isManualOverride: true,
    );
  }

  @override
  AssetMappingExplanation explainPlacement({
    required MediaAsset asset,
    required List<ClassificationLabel> labels,
  }) {
    return _pipeline.explainPlacement(asset: asset, labels: labels);
  }
}
