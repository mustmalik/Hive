import '../../application/repositories/scan_run_repository.dart';
import '../../domain/entities/scan_run.dart';
import 'local_scan_storage_codec.dart';
import '../services/local_scan_result_store.dart';

class LocalScanRunRepository implements ScanRunRepository {
  LocalScanRunRepository({required LocalScanResultStore store})
    : _store = store;

  final LocalScanResultStore _store;

  @override
  Future<ScanRun?> getLatestRun() async {
    final runs = await getRecentRuns(limit: 1);
    return runs.isEmpty ? null : runs.first;
  }

  @override
  Future<List<ScanRun>> getRecentRuns({int limit = 20}) async {
    final snapshot = await _store.read();
    return snapshot.runs
        .map(scanRunFromJson)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<void> saveRun(ScanRun run) async {
    final current = await getRecentRuns(limit: 50);
    final filtered = current
        .where((existing) => existing.id != run.id)
        .toList();
    filtered.insert(0, run);

    final snapshot = await _store.read();
    await _store.write(
      copyStoredScanSnapshot(
        snapshot,
        runs: filtered.map(scanRunToJson).toList(growable: false),
      ),
    );
  }
}
