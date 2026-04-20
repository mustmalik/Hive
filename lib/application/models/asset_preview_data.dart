import 'dart:typed_data';

class AssetPreviewData {
  const AssetPreviewData({
    this.filePath,
    this.bytes,
    this.isFullQuality = false,
    this.sourceLabel,
  });

  const AssetPreviewData.file({
    required String this.filePath,
    this.isFullQuality = false,
    this.sourceLabel,
  }) : bytes = null;

  const AssetPreviewData.memory({
    required Uint8List this.bytes,
    this.isFullQuality = false,
    this.sourceLabel,
  }) : filePath = null;

  final String? filePath;
  final Uint8List? bytes;
  final bool isFullQuality;
  final String? sourceLabel;

  bool get hasDisplayableContent => filePath != null || bytes != null;
}
