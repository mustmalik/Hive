import '../models/hive_cell_category.dart';

abstract interface class ManualRecategorizationService {
  List<HiveCellCategory> get availableTargetCells;

  Future<void> moveAssetToCell({
    required String assetId,
    required String targetCellId,
  });
}
