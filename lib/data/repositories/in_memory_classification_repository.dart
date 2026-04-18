import '../../application/models/classification_outcome.dart';
import '../../application/repositories/classification_repository.dart';
import '../../domain/entities/classification_label.dart';

class InMemoryClassificationRepository implements ClassificationRepository {
  InMemoryClassificationRepository({
    Map<String, List<ClassificationLabel>>? seedLabels,
    Map<String, ClassificationOutcome>? seedOutcomes,
  }) : _outcomesByAssetId = {
         for (final entry
             in (seedOutcomes ??
                     <String, ClassificationOutcome>{
                       for (final seeded
                           in (seedLabels ??
                                   const <String, List<ClassificationLabel>>{})
                               .entries)
                         seeded.key: ClassificationOutcome(
                           assetId: seeded.key,
                           status: seeded.value.isEmpty
                               ? ClassificationOutcomeStatus.noLabelsReturned
                               : ClassificationOutcomeStatus.succeeded,
                           labels: List<ClassificationLabel>.from(seeded.value),
                           classificationRan: true,
                           imagePreparationSucceeded: true,
                           noLabelsReturned: seeded.value.isEmpty,
                           modelIdentifier: seeded.value.isEmpty
                               ? null
                               : seeded.value.first.modelIdentifier,
                         ),
                     })
                 .entries)
           entry.key: entry.value,
       };

  final Map<String, ClassificationOutcome> _outcomesByAssetId;

  @override
  Future<void> clear() async {
    _outcomesByAssetId.clear();
  }

  @override
  Future<Map<String, ClassificationOutcome>> getOutcomesForAssetIds(
    List<String> assetIds,
  ) async {
    return {
      for (final assetId in assetIds)
        if (_outcomesByAssetId.containsKey(assetId))
          assetId: _outcomesByAssetId[assetId]!,
    };
  }

  @override
  Future<Map<String, List<ClassificationLabel>>> getLabelsForAssetIds(
    List<String> assetIds,
  ) async {
    return {
      for (final assetId in assetIds)
        if (_outcomesByAssetId.containsKey(assetId))
          assetId: List<ClassificationLabel>.unmodifiable(
            _outcomesByAssetId[assetId]!.labels,
          ),
    };
  }

  @override
  Future<void> saveLabelsForAsset(
    String assetId,
    List<ClassificationLabel> labels,
  ) async {
    await saveOutcome(
      ClassificationOutcome(
        assetId: assetId,
        status: labels.isEmpty
            ? ClassificationOutcomeStatus.noLabelsReturned
            : ClassificationOutcomeStatus.succeeded,
        labels: List<ClassificationLabel>.from(labels),
        classificationRan: true,
        imagePreparationSucceeded: true,
        noLabelsReturned: labels.isEmpty,
        modelIdentifier: labels.isEmpty ? null : labels.first.modelIdentifier,
      ),
    );
  }

  @override
  Future<void> saveOutcome(ClassificationOutcome outcome) async {
    _outcomesByAssetId[outcome.assetId] = outcome;
  }
}
