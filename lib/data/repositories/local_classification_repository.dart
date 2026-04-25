import '../../application/models/classification_outcome.dart';
import '../../application/repositories/classification_repository.dart';
import '../../domain/entities/classification_label.dart';
import '../services/local_scan_result_store.dart';
import 'local_scan_storage_codec.dart';

class LocalClassificationRepository implements ClassificationRepository {
  LocalClassificationRepository({required LocalScanResultStore store})
    : _store = store;

  final LocalScanResultStore _store;

  @override
  Future<void> clear() async {
    final snapshot = await _store.read();
    await _store.write(
      copyStoredScanSnapshot(
        snapshot,
        classifications: const <Map<String, dynamic>>[],
      ),
    );
  }

  @override
  Future<Map<String, ClassificationOutcome>> getOutcomesForAssetIds(
    List<String> assetIds,
  ) async {
    final requested = assetIds.toSet();
    final snapshot = await _store.read();
    final result = <String, ClassificationOutcome>{};

    for (final entry in snapshot.classifications) {
      final stored = classificationOutcomeFromJson(entry);
      if (requested.contains(stored.assetId)) {
        result[stored.assetId] = stored;
      }
    }

    return result;
  }

  @override
  Future<Map<String, List<ClassificationLabel>>> getLabelsForAssetIds(
    List<String> assetIds,
  ) async {
    final outcomes = await getOutcomesForAssetIds(assetIds);
    return {
      for (final entry in outcomes.entries) entry.key: entry.value.labels,
    };
  }

  @override
  Future<void> saveLabelsForAsset(
    String assetId,
    List<ClassificationLabel> labels,
  ) async {
    await saveOutcome(
      ClassificationOutcome(
        assetId: assetId,
        status: labels.isEmpty
            ? ClassificationOutcomeStatus.noLabelsReturned
            : ClassificationOutcomeStatus.succeeded,
        labels: labels,
        classificationRan: true,
        imagePreparationSucceeded: true,
        noLabelsReturned: labels.isEmpty,
        modelIdentifier: labels.isEmpty ? null : labels.first.modelIdentifier,
      ),
    );
  }

  @override
  Future<void> saveOutcome(ClassificationOutcome outcome) async {
    await saveOutcomes([outcome]);
  }

  @override
  Future<void> saveOutcomes(Iterable<ClassificationOutcome> outcomes) async {
    final snapshot = await _store.read();
    final existing = <String, Map<String, dynamic>>{};

    for (final entry in snapshot.classifications) {
      final id = entry['assetId'] as String?;
      if (id != null) {
        existing[id] = entry;
      }
    }

    for (final outcome in outcomes) {
      existing[outcome.assetId] = classificationOutcomeToJson(outcome);
    }

    await _store.write(
      copyStoredScanSnapshot(
        snapshot,
        classifications: existing.values.toList(growable: false),
      ),
    );
  }
}
