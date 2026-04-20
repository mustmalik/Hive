import 'package:photo_manager/photo_manager.dart';

import '../../application/models/media_album.dart';
import '../../application/models/scan_scope.dart';
import '../../application/services/media_library_service.dart';
import '../../domain/entities/media_asset.dart';

class PhotoManagerMediaLibraryService implements MediaLibraryService {
  const PhotoManagerMediaLibraryService();

  static const PermissionRequestOption _requestOption = PermissionRequestOption(
    iosAccessLevel: IosAccessLevel.readWrite,
  );

  static const FilterOption _assetFilterOption = FilterOption(needTitle: true);

  @override
  Future<List<MediaAsset>> fetchAssets({
    DateTime? updatedAfter,
    int page = 0,
    int pageSize = 200,
    ScanScope scope = const ScanScope.allPhotos(),
  }) async {
    if (!await _hasLibraryAccess()) {
      return const [];
    }

    final filter = _buildFilter(updatedAfter: updatedAfter);
    final entities = switch (scope.kind) {
      ScanScopeKind.allPhotos ||
      ScanScopeKind.limitedPhotos => await PhotoManager.getAssetListPaged(
        page: page,
        pageCount: pageSize,
        type: RequestType.common,
        filterOption: filter,
      ),
      ScanScopeKind.album => await _fetchScopedAlbumAssets(
        scope: scope,
        filter: filter,
        page: page,
        pageSize: pageSize,
      ),
    };

    return entities.map(_mapAssetEntity).toList(growable: false);
  }

  @override
  Future<List<MediaAlbum>> getAvailableAlbums({int limit = 24}) async {
    if (!await _hasLibraryAccess()) {
      return const [];
    }

    final paths = await PhotoManager.getAssetPathList(
      hasAll: false,
      type: RequestType.common,
      filterOption: _buildFilter(),
    );

    final albums = <MediaAlbum>[];

    for (final path in paths) {
      final refreshed = await _refreshPath(path, filter: _buildFilter());
      if (refreshed == null) {
        continue;
      }

      final assetCount = await _resolvePathAssetCount(refreshed);
      if (assetCount <= 0) {
        continue;
      }

      albums.add(
        MediaAlbum(
          id: refreshed.id,
          name: refreshed.name,
          assetCount: assetCount,
          isAll: refreshed.isAll,
          isFolder: refreshed.albumType != 1,
        ),
      );

      if (albums.length >= limit) {
        break;
      }
    }

    return albums;
  }

  @override
  Future<MediaAsset?> getAssetById(String assetId) async {
    if (!await _hasLibraryAccess()) {
      return null;
    }

    final entity = await AssetEntity.fromId(assetId);

    if (entity == null) {
      return null;
    }

    return _mapAssetEntity(entity);
  }

  @override
  Future<int> getEstimatedAssetCount({
    ScanScope scope = const ScanScope.allPhotos(),
  }) async {
    if (!await _hasLibraryAccess()) {
      return 0;
    }

    if (scope.kind == ScanScopeKind.album) {
      final path = await _resolveScopedPath(
        scope: scope,
        filter: _buildFilter(),
      );
      if (path == null) {
        return 0;
      }

      return _resolvePathAssetCount(path);
    }

    return PhotoManager.getAssetCount(
      type: RequestType.common,
      filterOption: _buildFilter(),
    );
  }

  FilterOptionGroup _buildFilter({DateTime? updatedAfter}) {
    return FilterOptionGroup(
      imageOption: _assetFilterOption,
      videoOption: _assetFilterOption,
      updateTimeCond: updatedAfter == null
          ? null
          : DateTimeCond(min: updatedAfter, max: DateTime.now()),
    );
  }

  Future<List<AssetEntity>> _fetchScopedAlbumAssets({
    required ScanScope scope,
    required FilterOptionGroup filter,
    required int page,
    required int pageSize,
  }) async {
    final path = await _resolveScopedPath(scope: scope, filter: filter);
    if (path == null) {
      return const [];
    }

    final leafAlbums = await _resolveLeafAlbums(path, filter: filter);
    if (leafAlbums.isEmpty) {
      return const [];
    }

    return _fetchAssetsFromAlbums(
      albums: leafAlbums,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<List<AssetEntity>> _fetchAssetsFromAlbums({
    required List<AssetPathEntity> albums,
    required int page,
    required int pageSize,
  }) async {
    var remainingOffset = page * pageSize;
    var remainingCount = pageSize;
    final entities = <AssetEntity>[];

    for (final album in albums) {
      final albumCount = await album.assetCountAsync;
      if (albumCount <= remainingOffset) {
        remainingOffset -= albumCount;
        continue;
      }

      final start = remainingOffset;
      final takeCount = (albumCount - start) < remainingCount
          ? (albumCount - start)
          : remainingCount;

      final fetched = await album.getAssetListRange(
        start: start,
        end: start + takeCount,
      );

      entities.addAll(fetched);
      remainingCount -= fetched.length;
      remainingOffset = 0;

      if (remainingCount <= 0) {
        break;
      }
    }

    return entities;
  }

  Future<AssetPathEntity?> _resolveScopedPath({
    required ScanScope scope,
    required FilterOptionGroup filter,
  }) async {
    final albumId = scope.albumId;
    if (albumId == null || albumId.isEmpty) {
      return null;
    }

    try {
      return AssetPathEntity.fromId(
        albumId,
        filterOption: filter,
        type: RequestType.common,
        albumType: scope.isFolder ? 2 : 1,
      );
    } catch (_) {
      return null;
    }
  }

  Future<AssetPathEntity?> _refreshPath(
    AssetPathEntity path, {
    required FilterOptionGroup filter,
  }) async {
    try {
      return AssetPathEntity.fromId(
        path.id,
        filterOption: filter,
        type: RequestType.common,
        albumType: path.albumType,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<AssetPathEntity>> _resolveLeafAlbums(
    AssetPathEntity path, {
    required FilterOptionGroup filter,
  }) async {
    if (path.albumType == 1) {
      return [path];
    }

    final subPaths = await path.getSubPathList();
    final leafAlbums = <AssetPathEntity>[];

    for (final subPath in subPaths) {
      final refreshed = await _refreshPath(subPath, filter: filter);
      if (refreshed == null) {
        continue;
      }

      if (refreshed.albumType == 1) {
        leafAlbums.add(refreshed);
      } else {
        leafAlbums.addAll(await _resolveLeafAlbums(refreshed, filter: filter));
      }
    }

    return leafAlbums;
  }

  Future<int> _resolvePathAssetCount(AssetPathEntity path) async {
    if (path.albumType == 1) {
      return path.assetCountAsync;
    }

    final leafAlbums = await _resolveLeafAlbums(path, filter: _buildFilter());
    var totalCount = 0;
    for (final album in leafAlbums) {
      totalCount += await album.assetCountAsync;
    }
    return totalCount;
  }

  Future<bool> _hasLibraryAccess() async {
    final state = await PhotoManager.getPermissionState(
      requestOption: _requestOption,
    );

    return switch (state) {
      PermissionState.authorized || PermissionState.limited => true,
      PermissionState.notDetermined ||
      PermissionState.denied ||
      PermissionState.restricted => false,
    };
  }

  MediaAsset _mapAssetEntity(AssetEntity entity) {
    final createdAt = _resolveCreatedAt(entity);
    final modifiedAt = _resolveModifiedAt(entity, fallback: createdAt);

    return MediaAsset(
      id: entity.id,
      type: _mapType(entity),
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      width: entity.width,
      height: entity.height,
      duration: entity.type == AssetType.video
          ? entity.videoDuration
          : Duration.zero,
      originalFilename: entity.title,
      isFavorite: entity.isFavorite,
    );
  }

  MediaAssetType _mapType(AssetEntity entity) {
    if (entity.isLivePhoto) {
      return MediaAssetType.livePhoto;
    }

    return switch (entity.type) {
      AssetType.image => MediaAssetType.image,
      AssetType.video => MediaAssetType.video,
      AssetType.audio || AssetType.other => MediaAssetType.other,
    };
  }

  DateTime _resolveCreatedAt(AssetEntity entity) {
    if (entity.createDateSecond != null && entity.createDateSecond! > 0) {
      return entity.createDateTime;
    }

    if (entity.modifiedDateSecond != null && entity.modifiedDateSecond! > 0) {
      return entity.modifiedDateTime;
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _resolveModifiedAt(
    AssetEntity entity, {
    required DateTime fallback,
  }) {
    if (entity.modifiedDateSecond != null && entity.modifiedDateSecond! > 0) {
      return entity.modifiedDateTime;
    }

    return fallback;
  }
}
