import '../models/classification_outcome.dart';
import '../../domain/entities/classification_label.dart';
import '../../domain/entities/media_asset.dart';

abstract class ClassificationService {
  Future<ClassificationOutcome> classifyAssetDetailed(MediaAsset asset);

  Future<List<ClassificationLabel>> classifyAsset(MediaAsset asset) async {
    final outcome = await classifyAssetDetailed(asset);
    return outcome.labels;
  }

  Future<Map<String, List<ClassificationLabel>>> classifyAssets(
    List<MediaAsset> assets,
  ) async {
    final results = <String, List<ClassificationLabel>>{};
    for (final asset in assets) {
      results[asset.id] = await classifyAsset(asset);
    }
    return results;
  }
}
