import '../../domain/entities/classification_label.dart';

enum UnsortedReason {
  lowConfidenceHuman,
  lowConfidenceFood,
  lowConfidenceScene,
  ambiguousMulti,
  noSignal,
}

enum UnsortedFallbackReason {
  lowConfidenceHuman,
  lowConfidenceFood,
  lowConfidenceScene,
  lowConfidenceAnimal,
  lowConfidenceSports,
  lowConfidenceDocument,
  ambiguousMulti,
  noSignal,
}

class AssetMappingExplanation {
  const AssetMappingExplanation({
    required this.cellId,
    required this.cellName,
    required this.score,
    required this.usedFallback,
    required this.topLabels,
    List<String>? matchedKeywords,
    List<String>? primaryEvidence,
    this.secondarySupport = const [],
    this.fallbackOrDebugReasons = const [],
    this.isManualOverride = false,
    this.fallbackReason,
    this.unsortedReason,
    this.topCandidateCellId,
    this.topCandidateCellName,
    this.topCandidateScore,
    this.runnerUpCellId,
    this.runnerUpCellName,
    this.runnerUpScore,
    this.winningMargin,
    this.requiredMargin,
    this.fallbackThreshold,
    this.blockedByMargin,
    this.blockedByLowConfidence,
    this.finalDecisionSummary,
  }) : primaryEvidence = primaryEvidence ?? matchedKeywords ?? const [],
       matchedKeywords = primaryEvidence ?? matchedKeywords ?? const [];

  final String cellId;
  final String cellName;
  final double score;
  final bool usedFallback;
  final List<ClassificationLabel> topLabels;
  final List<String> primaryEvidence;
  final List<String> secondarySupport;
  final List<String> fallbackOrDebugReasons;
  final List<String> matchedKeywords;
  final bool isManualOverride;
  final UnsortedFallbackReason? fallbackReason;
  final UnsortedReason? unsortedReason;
  final String? topCandidateCellId;
  final String? topCandidateCellName;
  final double? topCandidateScore;
  final String? runnerUpCellId;
  final String? runnerUpCellName;
  final double? runnerUpScore;
  final double? winningMargin;
  final double? requiredMargin;
  final double? fallbackThreshold;
  final bool? blockedByMargin;
  final bool? blockedByLowConfidence;
  final String? finalDecisionSummary;
}
