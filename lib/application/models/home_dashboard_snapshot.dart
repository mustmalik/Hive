import 'home_cell_preview.dart';

class HomeDashboardSnapshot {
  const HomeDashboardSnapshot({
    required this.totalAssetCount,
    required this.totalCellCount,
    required this.lastCompletedScanAt,
    required this.visibleCells,
    this.hasCompletedScan = false,
    this.meaningfulCellCount = 0,
  });

  final int totalAssetCount;
  final int totalCellCount;
  final DateTime? lastCompletedScanAt;
  final List<HomeCellPreview> visibleCells;
  final bool hasCompletedScan;
  final int meaningfulCellCount;

  bool get hasMeaningfulCells => meaningfulCellCount > 0;
}
