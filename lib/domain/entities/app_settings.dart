enum ThumbnailQuality { compact, balanced, detailed }

class AppSettings {
  const AppSettings({
    this.scanImages = true,
    this.scanVideos = true,
    this.allowSuggestedCells = true,
    this.preferLimitedLibraryManagement = true,
    this.thumbnailQuality = ThumbnailQuality.balanced,
    this.lastCompletedScanAt,
  });

  final bool scanImages;
  final bool scanVideos;
  final bool allowSuggestedCells;
  final bool preferLimitedLibraryManagement;
  final ThumbnailQuality thumbnailQuality;
  final DateTime? lastCompletedScanAt;
}
