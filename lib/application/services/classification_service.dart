import '../../domain/entities/classification_label.dart';
import '../../domain/entities/media_asset.dart';

abstract interface class ClassificationService {
  Future<List<ClassificationLabel>> classifyAsset(MediaAsset asset);

  Future<Map<String, List<ClassificationLabel>>> classifyAssets(
    List<MediaAsset> assets,
  );
}
