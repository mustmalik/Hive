import '../../application/repositories/media_asset_repository.dart';
import '../../domain/entities/media_asset.dart';

class InMemoryMediaAssetRepository implements MediaAssetRepository {
  InMemoryMediaAssetRepository({List<MediaAsset>? seedAssets})
    : _assets = List<MediaAsset>.from(seedAssets ?? _defaultAssets());

  final List<MediaAsset> _assets;

  factory InMemoryMediaAssetRepository.seeded() {
    return InMemoryMediaAssetRepository();
  }

  @override
  Future<void> clear() async {
    _assets.clear();
  }

  @override
  Future<List<MediaAsset>> getAllAssets() async {
    return List<MediaAsset>.unmodifiable(_assets);
  }

  @override
  Future<MediaAsset?> getAssetById(String assetId) async {
    for (final asset in _assets) {
      if (asset.id == assetId) {
        return asset;
      }
    }

    return null;
  }

  @override
  Future<void> upsertAssets(List<MediaAsset> assets) async {
    for (final asset in assets) {
      final index = _assets.indexWhere((existing) => existing.id == asset.id);

      if (index >= 0) {
        _assets[index] = asset;
      } else {
        _assets.add(asset);
      }
    }
  }

  @override
  Future<void> replaceAll(List<MediaAsset> assets) async {
    _assets
      ..clear()
      ..addAll(assets);
  }

  static List<MediaAsset> _defaultAssets() {
    final now = DateTime.now();

    return List<MediaAsset>.generate(529, (index) {
      final createdAt = now.subtract(Duration(days: index % 180, hours: index));

      return MediaAsset(
        id: 'asset_$index',
        type: index % 11 == 0 ? MediaAssetType.video : MediaAssetType.image,
        createdAt: createdAt,
        modifiedAt: createdAt.add(const Duration(hours: 2)),
        width: 1200 + (index % 6) * 120,
        height: 1600,
        duration: index % 11 == 0
            ? Duration(seconds: 12 + (index % 25))
            : Duration.zero,
        originalFilename: 'IMG_${index.toString().padLeft(4, '0')}.JPG',
        isFavorite: index % 17 == 0,
      );
    });
  }
}
