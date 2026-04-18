import 'home_cell_preview.dart';

class HomeDashboardSnapshot {
  const HomeDashboardSnapshot({
    required this.totalAssetCount,
    required this.totalCellCount,
    required this.lastCompletedScanAt,
    required this.visibleCells,
  });

  final int totalAssetCount;
  final int totalCellCount;
  final DateTime? lastCompletedScanAt;
  final List<HomeCellPreview> visibleCells;
}
