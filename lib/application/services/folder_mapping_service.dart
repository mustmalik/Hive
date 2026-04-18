import '../models/asset_mapping_explanation.dart';
import '../../domain/entities/classification_label.dart';
import '../../domain/entities/folder_cell.dart';
import '../../domain/entities/manual_override.dart';
import '../../domain/entities/media_asset.dart';

abstract interface class FolderMappingService {
  AssetMappingExplanation explainPlacement({
    required MediaAsset asset,
    required List<ClassificationLabel> labels,
  });

  Future<List<FolderCell>> buildSuggestedCells({
    required List<MediaAsset> assets,
    required Map<String, List<ClassificationLabel>> labelsByAssetId,
    List<ManualOverride> overrides = const [],
  });
}
