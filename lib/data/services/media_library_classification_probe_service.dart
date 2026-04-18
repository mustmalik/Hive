import '../../application/models/classification_probe_result.dart';
import '../../application/services/classification_probe_service.dart';
import '../../application/services/classification_service.dart';
import '../../application/services/media_library_service.dart';
import '../../domain/entities/media_asset.dart';

class MediaLibraryClassificationProbeService
    implements ClassificationProbeService {
  const MediaLibraryClassificationProbeService({
    required MediaLibraryService mediaLibraryService,
    required ClassificationService classificationService,
  }) : _mediaLibraryService = mediaLibraryService,
       _classificationService = classificationService;

  final MediaLibraryService _mediaLibraryService;
  final ClassificationService _classificationService;

  @override
  Future<ClassificationProbeResult?> classifyFirstAvailableAsset({
    int pageSize = 40,
  }) async {
    final assets = await _mediaLibraryService.fetchAssets(pageSize: pageSize);

    for (final asset in assets) {
      if (!_isClassifiable(asset)) {
        continue;
      }

      final labels = await _classificationService.classifyAsset(asset);
      return ClassificationProbeResult(asset: asset, labels: labels);
    }

    return null;
  }

  bool _isClassifiable(MediaAsset asset) {
    return asset.type == MediaAssetType.image ||
        asset.type == MediaAssetType.livePhoto ||
        asset.type == MediaAssetType.screenshot;
  }
}
