import 'package:photo_manager/photo_manager.dart';

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
  }) async {
    if (!await _hasLibraryAccess()) {
      return const [];
    }

    final entities = await PhotoManager.getAssetListPaged(
      page: page,
      pageCount: pageSize,
      type: RequestType.common,
      filterOption: _buildFilter(updatedAfter: updatedAfter),
    );

    return entities.map(_mapAssetEntity).toList(growable: false);
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
  Future<int> getEstimatedAssetCount() async {
    if (!await _hasLibraryAccess()) {
      return 0;
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
