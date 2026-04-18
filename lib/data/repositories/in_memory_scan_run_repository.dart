import '../../application/repositories/scan_run_repository.dart';
import '../../domain/entities/scan_run.dart';

class InMemoryScanRunRepository implements ScanRunRepository {
  InMemoryScanRunRepository({List<ScanRun>? seedRuns})
    : _runs = List<ScanRun>.from(seedRuns ?? _defaultRuns());

  final List<ScanRun> _runs;

  factory InMemoryScanRunRepository.seeded() {
    return InMemoryScanRunRepository();
  }

  @override
  Future<ScanRun?> getLatestRun() async {
    if (_runs.isEmpty) {
      return null;
    }

    return _runs.first;
  }

  @override
  Future<List<ScanRun>> getRecentRuns({int limit = 20}) async {
    return List<ScanRun>.unmodifiable(_runs.take(limit));
  }

  @override
  Future<void> saveRun(ScanRun run) async {
    final index = _runs.indexWhere((existing) => existing.id == run.id);

    if (index >= 0) {
      _runs[index] = run;
    } else {
      _runs.insert(0, run);
    }
  }

  static List<ScanRun> _defaultRuns() {
    final now = DateTime.now();

    return [
      ScanRun(
        id: 'scan_003',
        status: ScanRunStatus.completed,
        startedAt: now.subtract(const Duration(hours: 2, minutes: 20)),
        completedAt: now.subtract(const Duration(hours: 2)),
        discoveredAssetCount: 529,
        classifiedAssetCount: 0,
        generatedCellCount: 12,
      ),
      ScanRun(
        id: 'scan_002',
        status: ScanRunStatus.completed,
        startedAt: now.subtract(const Duration(days: 1, hours: 1)),
        completedAt: now.subtract(const Duration(days: 1)),
        discoveredAssetCount: 481,
        classifiedAssetCount: 0,
        generatedCellCount: 10,
      ),
    ];
  }
}
