import 'dart:typed_data';

import '../../domain/entities/media_asset.dart';

abstract interface class ThumbnailService {
  Future<Uint8List?> loadThumbnail({required MediaAsset asset, int size = 256});

  Future<void> clearCache();
}
