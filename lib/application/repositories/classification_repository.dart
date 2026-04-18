import '../../domain/entities/classification_label.dart';

abstract interface class ClassificationRepository {
  Future<void> saveLabelsForAsset(
    String assetId,
    List<ClassificationLabel> labels,
  );

  Future<Map<String, List<ClassificationLabel>>> getLabelsForAssetIds(
    List<String> assetIds,
  );

  Future<void> clear();
}
