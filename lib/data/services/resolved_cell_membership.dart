import '../../application/models/asset_mapping_explanation.dart';
import '../../application/services/folder_mapping_service.dart';
import '../../domain/entities/classification_label.dart';
import '../../domain/entities/manual_override.dart';
import '../../domain/entities/media_asset.dart';

Map<String, ManualOverride> latestIncludeOverridesByAssetId(
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

String resolveCellIdForAsset({
  required MediaAsset asset,
  required List<ClassificationLabel> labels,
  required FolderMappingService folderMappingService,
  ManualOverride? override,
}) {
  if (override?.cellId case final overrideCellId?) {
    return overrideCellId == 'animation_cartoon_meme' ? 'memes' : overrideCellId;
  }

  final resolved = folderMappingService
      .explainPlacement(asset: asset, labels: labels)
      .cellId;
  return resolved == 'animation_cartoon_meme' ? 'memes' : resolved;
}

AssetMappingExplanation? resolveCellExplanationForAsset({
  required String selectedCellId,
  required String selectedCellName,
  required MediaAsset asset,
  required List<ClassificationLabel> labels,
  required FolderMappingService folderMappingService,
  ManualOverride? override,
}) {
  if (override?.cellId case final overrideCellId?) {
    final normalizedOverrideCellId =
        overrideCellId == 'animation_cartoon_meme' ? 'memes' : overrideCellId;
    if (normalizedOverrideCellId != selectedCellId) {
      return null;
    }

    return AssetMappingExplanation(
      cellId: selectedCellId,
      cellName: selectedCellName,
      score: 1.5,
      usedFallback: false,
      topLabels: labels,
      matchedKeywords: const ['manual override'],
      isManualOverride: true,
    );
  }

  final explanation = folderMappingService.explainPlacement(
    asset: asset,
    labels: labels,
  );
  final normalizedCellId =
      explanation.cellId == 'animation_cartoon_meme' ? 'memes' : explanation.cellId;
  if (normalizedCellId != selectedCellId) {
    return null;
  }

  return normalizedCellId == explanation.cellId
      ? explanation
      : AssetMappingExplanation(
          cellId: normalizedCellId,
          cellName: selectedCellName,
          score: explanation.score,
          usedFallback: explanation.usedFallback,
          topLabels: explanation.topLabels,
          primaryEvidence: explanation.primaryEvidence,
          secondarySupport: explanation.secondarySupport,
          fallbackOrDebugReasons: explanation.fallbackOrDebugReasons,
          matchedKeywords: explanation.matchedKeywords,
          isManualOverride: explanation.isManualOverride,
          fallbackReason: explanation.fallbackReason,
          unsortedReason: explanation.unsortedReason,
          topCandidateCellId: explanation.topCandidateCellId,
          topCandidateCellName: explanation.topCandidateCellName,
          topCandidateScore: explanation.topCandidateScore,
          runnerUpCellId: explanation.runnerUpCellId,
          runnerUpCellName: explanation.runnerUpCellName,
          runnerUpScore: explanation.runnerUpScore,
          winningMargin: explanation.winningMargin,
          requiredMargin: explanation.requiredMargin,
          fallbackThreshold: explanation.fallbackThreshold,
          blockedByMargin: explanation.blockedByMargin,
          blockedByLowConfidence: explanation.blockedByLowConfidence,
          finalDecisionSummary: explanation.finalDecisionSummary,
        );
}
