import 'package:flutter/foundation.dart';

import '../../domain/entities/folder_cell.dart';

void debugResultsLog(String message) {
  if (!kDebugMode) {
    return;
  }

  debugPrint('[HIVE-RESULTS] $message');
}

String debugIdSet(Iterable<String> ids) {
  final sorted = ids.toSet().toList(growable: false)..sort();
  return '{${sorted.join(', ')}}';
}

String debugCellAssetMap(Map<String, Iterable<String>> assetIdsByCellId) {
  final cellIds = assetIdsByCellId.keys.toList(growable: false)..sort();
  return cellIds
      .map((cellId) => '$cellId=${debugIdSet(assetIdsByCellId[cellId] ?? [])}')
      .join(' ');
}

String debugFolderCells(Iterable<FolderCell> cells) {
  final assetIdsByCellId = {for (final cell in cells) cell.id: cell.assetIds};
  return debugCellAssetMap(assetIdsByCellId);
}

Set<String> uniqueAssetIdsInCells(Iterable<FolderCell> cells) {
  return {
    for (final cell in cells)
      for (final assetId in cell.assetIds) assetId,
  };
}

Set<String> missingIds({
  required Iterable<String> expected,
  required Iterable<String> actual,
}) {
  return expected.toSet().difference(actual.toSet());
}
