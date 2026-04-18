enum ScanRunStatus { queued, running, completed, failed, canceled }

class ScanRun {
  const ScanRun({
    required this.id,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.discoveredAssetCount = 0,
    this.classifiedAssetCount = 0,
    this.generatedCellCount = 0,
    this.errorMessage,
    this.currentStageLabel,
    this.currentItemTitle,
    this.latestDetectedCellName,
  });

  final String id;
  final ScanRunStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int discoveredAssetCount;
  final int classifiedAssetCount;
  final int generatedCellCount;
  final String? errorMessage;
  final String? currentStageLabel;
  final String? currentItemTitle;
  final String? latestDetectedCellName;

  double get progress => discoveredAssetCount == 0
      ? 0
      : classifiedAssetCount / discoveredAssetCount;

  bool get isRunning =>
      status == ScanRunStatus.queued || status == ScanRunStatus.running;

  bool get isTerminal =>
      status == ScanRunStatus.completed ||
      status == ScanRunStatus.failed ||
      status == ScanRunStatus.canceled;
}
