import '../../domain/entities/media_asset.dart';

abstract interface class MediaLibraryService {
  Future<int> getEstimatedAssetCount();

  Future<List<MediaAsset>> fetchAssets({
    DateTime? updatedAfter,
    int page = 0,
    int pageSize = 200,
  });

  Future<MediaAsset?> getAssetById(String assetId);
}
