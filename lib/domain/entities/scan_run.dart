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
  });

  final String id;
  final ScanRunStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int discoveredAssetCount;
  final int classifiedAssetCount;
  final int generatedCellCount;
  final String? errorMessage;

  bool get isTerminal =>
      status == ScanRunStatus.completed ||
      status == ScanRunStatus.failed ||
      status == ScanRunStatus.canceled;
}
