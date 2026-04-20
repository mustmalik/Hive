import '../models/scan_scope.dart';
import '../../domain/entities/scan_run.dart';

abstract interface class ScanCoordinator {
  Stream<ScanRun> watchActiveRun();

  Future<ScanRun?> getLatestRun();

  Future<ScanRun> startFullScan({
    ScanScope scope = const ScanScope.allPhotos(),
  });

  Future<void> cancelActiveRun();
}
