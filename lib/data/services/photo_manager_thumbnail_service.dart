import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

import '../../application/services/thumbnail_service.dart';
import '../../domain/entities/media_asset.dart';

class PhotoManagerThumbnailService implements ThumbnailService {
  const PhotoManagerThumbnailService();

  @override
  Future<void> clearCache() async {}

  @override
  Future<Uint8List?> loadThumbnail({
    required MediaAsset asset,
    int size = 256,
  }) async {
    final entity = await AssetEntity.fromId(asset.id);
    if (entity == null) {
      return null;
    }

    return entity.thumbnailDataWithSize(
      ThumbnailSize.square(size),
      quality: 84,
    );
  }
}
