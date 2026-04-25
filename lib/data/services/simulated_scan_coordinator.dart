import 'dart:async';
import 'dart:math' as math;

import '../../application/models/scan_scope.dart';
import '../../application/repositories/scan_run_repository.dart';
import '../../application/services/media_library_service.dart';
import '../../application/services/scan_coordinator.dart';
import '../../domain/entities/scan_run.dart';
import '../repositories/in_memory_scan_run_repository.dart';
import 'photo_manager_media_library_service.dart';

class SimulatedScanCoordinator implements ScanCoordinator {
  SimulatedScanCoordinator({
    required MediaLibraryService mediaLibraryService,
    required ScanRunRepository scanRunRepository,
  }) : _mediaLibraryService = mediaLibraryService,
       _scanRunRepository = scanRunRepository;

  final MediaLibraryService _mediaLibraryService;
  final ScanRunRepository _scanRunRepository;
  final StreamController<ScanRun> _controller =
      StreamController<ScanRun>.broadcast();

  Timer? _timer;
  ScanRun? _activeRun;
  int _tick = 0;

  static const List<String> _currentItems = [
    'IMG_1042.JPG',
    'IMG_1189.JPG',
    'IMG_1264.HEIC',
    'VID_0217.MOV',
    'IMG_1308.JPG',
    'IMG_1312.JPG',
    'IMG_1430.HEIC',
  ];

  static const List<String> _detectedCells = [
    'People',
    'Pets',
    'Places',
    'Food',
    'Sports',
    'Unsorted',
  ];

  factory SimulatedScanCoordinator.seeded() {
    return SimulatedScanCoordinator(
      mediaLibraryService: const PhotoManagerMediaLibraryService(),
      scanRunRepository: InMemoryScanRunRepository.seeded(),
    );
  }

  @override
  Future<void> cancelActiveRun() async {
    final run = _activeRun;

    if (run == null || run.isTerminal) {
      return;
    }

    _timer?.cancel();

    final canceledRun = ScanRun(
      id: run.id,
      status: ScanRunStatus.canceled,
      startedAt: run.startedAt,
      completedAt: DateTime.now(),
      discoveredAssetCount: run.discoveredAssetCount,
      classifiedAssetCount: run.classifiedAssetCount,
      generatedCellCount: run.generatedCellCount,
      currentStageLabel: 'Scan canceled',
      currentItemTitle: run.currentItemTitle,
      latestDetectedCellName: run.latestDetectedCellName,
    );

    await _emitRun(canceledRun);
  }

  @override
  Future<ScanRun?> getLatestRun() {
    return _scanRunRepository.getLatestRun();
  }

  @override
  Future<ScanRun> startFullScan({
    ScanScope scope = const ScanScope.allPhotos(),
  }) async {
    final currentRun = _activeRun;

    if (currentRun != null && !currentRun.isTerminal) {
      return currentRun;
    }

    final totalAssets = await _resolveTotalAssets(scope: scope);
    final now = DateTime.now();
    final runId = 'scan_${now.millisecondsSinceEpoch}';

    final queuedRun = ScanRun(
      id: runId,
      status: ScanRunStatus.queued,
      startedAt: now,
      discoveredAssetCount: totalAssets,
      classifiedAssetCount: 0,
      generatedCellCount: 0,
      currentStageLabel: 'Preparing your library',
      currentItemTitle: 'Connecting to Apple Photos',
    );

    _tick = 0;
    await _emitRun(queuedRun);
    _startTimer();
    return queuedRun;
  }

  @override
  Stream<ScanRun> watchActiveRun() => _controller.stream;

  Future<void> _emitRun(ScanRun run) async {
    _activeRun = run;
    await _scanRunRepository.saveRun(run);
    if (!_controller.isClosed) {
      _controller.add(run);
    }
  }

  Future<int> _resolveTotalAssets({required ScanScope scope}) async {
    try {
      final total = await _mediaLibraryService.getEstimatedAssetCount(
        scope: scope,
      );
      return total > 0 ? total : 529;
    } catch (_) {
      return 529;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 240), (_) async {
      final current = _activeRun;

      if (current == null || current.isTerminal) {
        _timer?.cancel();
        return;
      }

      _tick += 1;
      final total = math.max(current.discoveredAssetCount, 1);
      final step = math.max(1, (total / 22).round());
      final nextCount = math.min(total, current.classifiedAssetCount + step);
      final nextCells = math.min(
        _detectedCells.length,
        math.max(1, (nextCount / math.max(1, total / 5)).floor()),
      );

      final isComplete = nextCount >= total;
      final nextRun = ScanRun(
        id: current.id,
        status: isComplete ? ScanRunStatus.completed : ScanRunStatus.running,
        startedAt: current.startedAt,
        completedAt: isComplete ? DateTime.now() : null,
        discoveredAssetCount: total,
        classifiedAssetCount: nextCount,
        generatedCellCount: nextCells,
        currentStageLabel: isComplete
            ? 'Cells ready'
            : _tick < 3
            ? 'Reading library metadata'
            : _tick < 8
            ? 'Grouping moments into cells'
            : 'Refining suggestions',
        currentItemTitle: isComplete
            ? 'Finishing your HIVE overview'
            : _currentItems[_tick % _currentItems.length],
        latestDetectedCellName:
            _detectedCells[(nextCells - 1).clamp(0, _detectedCells.length - 1)],
      );

      await _emitRun(nextRun);

      if (isComplete) {
        _timer?.cancel();
      }
    });
  }
}
