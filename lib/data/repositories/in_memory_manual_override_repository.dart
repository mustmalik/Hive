import '../../application/repositories/manual_override_repository.dart';
import '../../domain/entities/manual_override.dart';

class InMemoryManualOverrideRepository implements ManualOverrideRepository {
  InMemoryManualOverrideRepository({
    List<ManualOverride>? seedOverrides,
  }) : _overrides = List<ManualOverride>.from(seedOverrides ?? const []);

  final List<ManualOverride> _overrides;

  @override
  Future<void> clear() async {
    _overrides.clear();
  }

  @override
  Future<List<ManualOverride>> getAllOverrides() async {
    return List<ManualOverride>.unmodifiable(_overrides);
  }

  @override
  Future<List<ManualOverride>> getOverridesForAsset(String assetId) async {
    return _overrides
        .where((override) => override.assetId == assetId)
        .toList(growable: false);
  }

  @override
  Future<void> saveOverride(ManualOverride override) async {
    _overrides.removeWhere(
      (stored) =>
          stored.assetId == override.assetId &&
          stored.action == override.action &&
          stored.cellId != null,
    );
    _overrides.add(override);
  }
}
