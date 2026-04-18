enum ClassificationLabelSource {
  heuristic,
  onDeviceModel,
  manualOverride,
  imported,
}

class ClassificationLabel {
  const ClassificationLabel({
    required this.id,
    required this.key,
    required this.displayName,
    required this.confidence,
    required this.source,
    required this.createdAt,
    this.modelIdentifier,
  });

  final String id;
  final String key;
  final String displayName;
  final double confidence;
  final ClassificationLabelSource source;
  final DateTime createdAt;
  final String? modelIdentifier;

  bool get isHighConfidence => confidence >= 0.8;
}
