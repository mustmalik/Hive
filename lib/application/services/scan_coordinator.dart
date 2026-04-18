import '../../domain/entities/scan_run.dart';

abstract interface class ScanCoordinator {
  Stream<ScanRun> watchActiveRun();

  Future<ScanRun?> getLatestRun();

  Future<ScanRun> startFullScan();

  Future<void> cancelActiveRun();
}
