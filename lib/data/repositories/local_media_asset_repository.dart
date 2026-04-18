import '../../application/repositories/media_asset_repository.dart';
import '../../domain/entities/media_asset.dart';
import 'local_scan_storage_codec.dart';
import '../services/local_scan_result_store.dart';

class LocalMediaAssetRepository implements MediaAssetRepository {
  LocalMediaAssetRepository({required LocalScanResultStore store})
    : _store = store;

  final LocalScanResultStore _store;

  @override
  Future<void> clear() async {
    final snapshot = await _store.read();
    await _store.write(
      copyStoredScanSnapshot(snapshot, assets: const <Map<String, dynamic>>[]),
    );
  }

  @override
  Future<List<MediaAsset>> getAllAssets() async {
    final snapshot = await _store.read();
    return snapshot.assets.map(mediaAssetFromJson).toList(growable: false);
  }

  @override
  Future<MediaAsset?> getAssetById(String assetId) async {
    final assets = await getAllAssets();
    for (final asset in assets) {
      if (asset.id == assetId) {
        return asset;
      }
    }

    return null;
  }

  @override
  Future<void> upsertAssets(List<MediaAsset> assets) async {
    final snapshot = await _store.read();
    final existing = <String, Map<String, dynamic>>{};
    for (final item in snapshot.assets) {
      final id = item['id'] as String?;
      if (id != null) {
        existing[id] = item;
      }
    }

    for (final asset in assets) {
      existing[asset.id] = mediaAssetToJson(asset);
    }

    await _store.write(
      copyStoredScanSnapshot(
        snapshot,
        assets: existing.values.toList(growable: false),
      ),
    );
  }

  Future<void> replaceAll(List<MediaAsset> assets) async {
    final snapshot = await _store.read();
    await _store.write(
      copyStoredScanSnapshot(
        snapshot,
        assets: assets.map(mediaAssetToJson).toList(growable: false),
      ),
    );
  }
}
