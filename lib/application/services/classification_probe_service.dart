import '../models/classification_probe_result.dart';

abstract interface class ClassificationProbeService {
  Future<ClassificationProbeResult?> classifyFirstAvailableAsset({
    int pageSize = 40,
  });

  Future<ClassificationProbeResult?> classifyAssetById(String assetId);
}
