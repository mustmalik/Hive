import '../../application/repositories/manual_override_repository.dart';
import '../../domain/entities/manual_override.dart';
import '../services/local_scan_result_store.dart';
import 'local_scan_storage_codec.dart';

class LocalManualOverrideRepository implements ManualOverrideRepository {
  LocalManualOverrideRepository({required LocalScanResultStore store})
    : _store = store;

  final LocalScanResultStore _store;

  @override
  Future<void> clear() async {
    final snapshot = await _store.read();
    await _store.write(
      copyStoredScanSnapshot(
        snapshot,
        overrides: const <Map<String, dynamic>>[],
      ),
    );
  }

  @override
  Future<List<ManualOverride>> getAllOverrides() async {
    final snapshot = await _store.read();
    return snapshot.overrides
        .map(manualOverrideFromJson)
        .toList(growable: false);
  }

  @override
  Future<List<ManualOverride>> getOverridesForAsset(String assetId) async {
    final overrides = await getAllOverrides();
    return overrides
        .where((override) => override.assetId == assetId)
        .toList(growable: false);
  }

  @override
  Future<void> saveOverride(ManualOverride override) async {
    final snapshot = await _store.read();
    final existing = <String, Map<String, dynamic>>{};

    for (final item in snapshot.overrides) {
      final stored = manualOverrideFromJson(item);
      if (stored.assetId == override.assetId &&
          stored.action == override.action &&
          stored.cellId != null) {
        continue;
      }

      existing[stored.id] = item;
    }

    existing[override.id] = manualOverrideToJson(override);

    await _store.write(
      copyStoredScanSnapshot(
        snapshot,
        overrides: existing.values.toList(growable: false),
      ),
    );
  }
}
