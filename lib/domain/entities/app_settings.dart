import '../../application/models/scan_scope.dart';

enum ThumbnailQuality { compact, balanced, detailed }

class AppSettings {
  const AppSettings({
    this.hasCompletedOnboarding = false,
    this.scanImages = true,
    this.scanVideos = true,
    this.allowSuggestedCells = true,
    this.preferLimitedLibraryManagement = true,
    this.thumbnailQuality = ThumbnailQuality.balanced,
    this.lastCompletedScanAt,
    this.lastUsedScanScope,
  });

  final bool hasCompletedOnboarding;
  final bool scanImages;
  final bool scanVideos;
  final bool allowSuggestedCells;
  final bool preferLimitedLibraryManagement;
  final ThumbnailQuality thumbnailQuality;
  final DateTime? lastCompletedScanAt;
  final ScanScope? lastUsedScanScope;

  AppSettings copyWith({
    bool? hasCompletedOnboarding,
    bool? scanImages,
    bool? scanVideos,
    bool? allowSuggestedCells,
    bool? preferLimitedLibraryManagement,
    ThumbnailQuality? thumbnailQuality,
    DateTime? lastCompletedScanAt,
    bool clearLastCompletedScanAt = false,
    ScanScope? lastUsedScanScope,
    bool clearLastUsedScanScope = false,
  }) {
    return AppSettings(
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      scanImages: scanImages ?? this.scanImages,
      scanVideos: scanVideos ?? this.scanVideos,
      allowSuggestedCells: allowSuggestedCells ?? this.allowSuggestedCells,
      preferLimitedLibraryManagement:
          preferLimitedLibraryManagement ?? this.preferLimitedLibraryManagement,
      thumbnailQuality: thumbnailQuality ?? this.thumbnailQuality,
      lastCompletedScanAt: clearLastCompletedScanAt
          ? null
          : lastCompletedScanAt ?? this.lastCompletedScanAt,
      lastUsedScanScope: clearLastUsedScanScope
          ? null
          : lastUsedScanScope ?? this.lastUsedScanScope,
    );
  }
}
