import '../../domain/entities/classification_label.dart';

enum ClassificationOutcomeStatus {
  succeeded,
  unsupportedAsset,
  imagePreparationFailed,
  noLabelsReturned,
  requestFailed,
}

class ClassificationOutcome {
  const ClassificationOutcome({
    required this.assetId,
    required this.status,
    this.labels = const [],
    this.failureReason,
    this.failureStage,
    this.failureCode,
    this.modelIdentifier,
    this.sourceFormat,
    this.preparedFormat,
    this.classificationRan = false,
    this.imagePreparationSucceeded = false,
    this.noLabelsReturned = false,
  });

  final String assetId;
  final ClassificationOutcomeStatus status;
  final List<ClassificationLabel> labels;
  final String? failureReason;
  final String? failureStage;
  final String? failureCode;
  final String? modelIdentifier;
  final String? sourceFormat;
  final String? preparedFormat;
  final bool classificationRan;
  final bool imagePreparationSucceeded;
  final bool noLabelsReturned;

  bool get succeeded => status == ClassificationOutcomeStatus.succeeded;
}
