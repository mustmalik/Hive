import '../../domain/entities/scan_run.dart';

abstract interface class ScanRunRepository {
  Future<void> saveRun(ScanRun run);

  Future<ScanRun?> getLatestRun();

  Future<List<ScanRun>> getRecentRuns({int limit = 20});
}
