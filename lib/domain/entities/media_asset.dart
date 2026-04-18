enum MediaAssetType { image, video, livePhoto, screenshot, other }

class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.modifiedAt,
    required this.width,
    required this.height,
    this.duration = Duration.zero,
    this.originalFilename,
    this.isFavorite = false,
    this.isHidden = false,
  });

  final String id;
  final MediaAssetType type;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final int width;
  final int height;
  final Duration duration;
  final String? originalFilename;
  final bool isFavorite;
  final bool isHidden;

  double get aspectRatio => height == 0 ? 1 : width / height;

  bool get isVideo =>
      type == MediaAssetType.video || type == MediaAssetType.livePhoto;
}
