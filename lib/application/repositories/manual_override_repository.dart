import '../../domain/entities/manual_override.dart';

abstract interface class ManualOverrideRepository {
  Future<void> saveOverride(ManualOverride override);

  Future<List<ManualOverride>> getAllOverrides();

  Future<List<ManualOverride>> getOverridesForAsset(String assetId);

  Future<void> clear();
}
