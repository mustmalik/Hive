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

  Future<List<MediaAlbum>> getAvailableAlbums({int limit = 24});

  Future<MediaAsset?> getAssetById(String assetId);
}
