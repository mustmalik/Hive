import '../models/folder_detail_item.dart';

abstract interface class AssetReclassificationService {
  Future<FolderDetailItem?> reclassifyAsset({required String assetId});
}
