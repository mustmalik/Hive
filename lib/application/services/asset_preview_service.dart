import '../models/asset_preview_data.dart';
import '../../domain/entities/media_asset.dart';

abstract interface class AssetPreviewService {
  Future<AssetPreviewData?> loadPreview({required MediaAsset asset});
}
