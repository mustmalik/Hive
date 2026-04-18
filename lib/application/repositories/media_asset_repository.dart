import '../../domain/entities/media_asset.dart';

abstract interface class MediaAssetRepository {
  Future<void> upsertAssets(List<MediaAsset> assets);

  Future<List<MediaAsset>> getAllAssets();

  Future<MediaAsset?> getAssetById(String assetId);

  Future<void> clear();
}
