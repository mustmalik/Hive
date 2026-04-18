import '../../domain/entities/classification_label.dart';
import '../../domain/entities/media_asset.dart';

class ClassificationProbeResult {
  const ClassificationProbeResult({required this.asset, required this.labels});

  final MediaAsset asset;
  final List<ClassificationLabel> labels;
}
