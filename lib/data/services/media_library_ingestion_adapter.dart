import '../../application/repositories/media_asset_repository.dart';
import '../../application/services/media_library_service.dart';
import '../../domain/entities/media_asset.dart';

class MediaLibraryIngestionAdapter {
  const MediaLibraryIngestionAdapter({
    required MediaLibraryService mediaLibraryService,
    required MediaAssetRepository mediaAssetRepository,
  }) : _mediaLibraryService = mediaLibraryService,
       _mediaAssetRepository = mediaAssetRepository;

  final MediaLibraryService _mediaLibraryService;
  final MediaAssetRepository _mediaAssetRepository;

  Future<List<MediaAsset>> ingestPage({
    DateTime? updatedAfter,
    int page = 0,
    int pageSize = 200,
  }) async {
    final assets = await _mediaLibraryService.fetchAssets(
      updatedAfter: updatedAfter,
      page: page,
      pageSize: pageSize,
    );

    if (assets.isNotEmpty) {
      await _mediaAssetRepository.upsertAssets(assets);
    }

    return assets;
  }

  Future<MediaAsset?> ingestAssetById(String assetId) async {
    final asset = await _mediaLibraryService.getAssetById(assetId);

    if (asset != null) {
      await _mediaAssetRepository.upsertAssets([asset]);
    }

    return asset;
  }
}
