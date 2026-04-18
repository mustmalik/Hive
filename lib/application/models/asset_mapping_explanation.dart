import '../../domain/entities/classification_label.dart';

class AssetMappingExplanation {
  const AssetMappingExplanation({
    required this.cellId,
    required this.cellName,
    required this.score,
    required this.usedFallback,
    required this.topLabels,
    this.matchedKeywords = const [],
  });

  final String cellId;
  final String cellName;
  final double score;
  final bool usedFallback;
  final List<ClassificationLabel> topLabels;
  final List<String> matchedKeywords;
}
