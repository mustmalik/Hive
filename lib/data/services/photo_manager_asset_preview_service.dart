import 'package:photo_manager/photo_manager.dart';

import '../../application/models/asset_preview_data.dart';
import '../../application/services/asset_preview_service.dart';
import '../../domain/entities/media_asset.dart';

class PhotoManagerAssetPreviewService implements AssetPreviewService {
  const PhotoManagerAssetPreviewService();

  @override
  Future<AssetPreviewData?> loadPreview({required MediaAsset asset}) async {
    try {
      final entity = await AssetEntity.fromId(asset.id);
      if (entity == null) {
        return null;
      }

      if (!asset.isVideo) {
        final originFile = await entity.originFile;
        if (originFile != null) {
          return AssetPreviewData.file(
            filePath: originFile.path,
            isFullQuality: true,
            sourceLabel: 'Original image',
          );
        }

        final compressedFile = await entity.file;
        if (compressedFile != null) {
          return AssetPreviewData.file(
            filePath: compressedFile.path,
            sourceLabel: 'Library preview',
          );
        }

        final originBytes = await entity.originBytes;
        if (originBytes != null) {
          return AssetPreviewData.memory(
            bytes: originBytes,
            isFullQuality: true,
            sourceLabel: 'Original image',
          );
        }
      }

      final previewWidth = (asset.width > 0 ? asset.width : 1800)
          .clamp(1200, 2200)
          .toInt();
      final previewHeight = (asset.height > 0 ? asset.height : 1800)
          .clamp(1200, 2200)
          .toInt();

      final previewBytes = await entity.thumbnailDataWithSize(
        ThumbnailSize(previewWidth, previewHeight),
        quality: 92,
      );
      if (previewBytes == null) {
        return null;
      }

      return AssetPreviewData.memory(
        bytes: previewBytes,
        sourceLabel: asset.isVideo ? 'Video still' : 'High-quality preview',
      );
    } catch (_) {
      return null;
    }
  }
}
