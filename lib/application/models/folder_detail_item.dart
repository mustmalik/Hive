import 'asset_mapping_explanation.dart';
import 'classification_outcome.dart';
import '../../domain/entities/media_asset.dart';

class FolderDetailItem {
  const FolderDetailItem({
    required this.asset,
    required this.title,
    required this.subtitle,
    this.mappingExplanation,
    this.classificationOutcome,
  });

  final MediaAsset asset;
  final String title;
  final String subtitle;
  final AssetMappingExplanation? mappingExplanation;
  final ClassificationOutcome? classificationOutcome;
}
