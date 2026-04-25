import '../models/classification_outcome.dart';
import '../../domain/entities/classification_label.dart';

abstract interface class ClassificationRepository {
  Future<void> saveOutcome(ClassificationOutcome outcome);

  Future<void> saveOutcomes(Iterable<ClassificationOutcome> outcomes);

  Future<Map<String, ClassificationOutcome>> getOutcomesForAssetIds(
    List<String> assetIds,
  );

  Future<void> saveLabelsForAsset(
    String assetId,
    List<ClassificationLabel> labels,
  );

  Future<Map<String, List<ClassificationLabel>>> getLabelsForAssetIds(
    List<String> assetIds,
  );

  Future<void> clear();
}
