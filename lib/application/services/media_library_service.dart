import '../models/media_album.dart';
import '../models/scan_scope.dart';
import '../../domain/entities/media_asset.dart';

abstract interface class MediaLibraryService {
  Future<int> getEstimatedAssetCount({
    ScanScope scope = const ScanScope.allPhotos(),
  });

  Future<List<MediaAsset>> fetchAssets({
    DateTime? updatedAfter,
    int page = 0,
    int pageSize = 200,
    ScanScope scope = const ScanScope.allPhotos(),
  });

  Future<List<PhotoAlbum>> fetchAlbums({int limit = 24});

  Future<List<MediaAlbum>> getAvailableAlbums({int limit = 24});

  Future<MediaAsset?> getAssetById(String assetId);
}

extension MediaLibraryScanScopeResolver on MediaLibraryService {
  Future<List<MediaAsset>> resolveAssetsForScope(
    ScanScope scope, {
    DateTime? updatedAfter,
    int pageSize = 200,
  }) async {
    assert(pageSize > 0, 'pageSize must be greater than zero.');

    final resolved = <MediaAsset>[];
    var page = 0;

    while (true) {
      final batch = await fetchAssets(
        updatedAfter: updatedAfter,
        page: page,
        pageSize: pageSize,
        scope: scope,
      );
      if (batch.isEmpty) {
        break;
      }

      resolved.addAll(batch);
      if (batch.length < pageSize) {
        break;
      }

      page += 1;
    }

    return List<MediaAsset>.unmodifiable(resolved);
  }
}
