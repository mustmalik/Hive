import '../../application/repositories/folder_cell_repository.dart';
import '../../domain/entities/folder_cell.dart';
import 'local_scan_storage_codec.dart';
import '../services/local_scan_result_store.dart';

class LocalFolderCellRepository implements FolderCellRepository {
  LocalFolderCellRepository({required LocalScanResultStore store})
    : _store = store;

  final LocalScanResultStore _store;

  @override
  Future<void> clear() async {
    final snapshot = await _store.read();
    await _store.write(
      copyStoredScanSnapshot(snapshot, cells: const <Map<String, dynamic>>[]),
    );
  }

  @override
  Future<List<FolderCell>> getAllCells() async {
    final snapshot = await _store.read();
    return snapshot.cells.map(folderCellFromJson).toList(growable: false);
  }

  @override
  Future<FolderCell?> getCellById(String cellId) async {
    final cells = await getAllCells();
    for (final cell in cells) {
      if (cell.id == cellId) {
        return cell;
      }
    }

    return null;
  }

  @override
  Future<void> saveCells(List<FolderCell> cells) async {
    final snapshot = await _store.read();
    final existing = <String, Map<String, dynamic>>{};
    for (final item in snapshot.cells) {
      final id = item['id'] as String?;
      if (id != null) {
        existing[id] = item;
      }
    }

    for (final cell in cells) {
      existing[cell.id] = folderCellToJson(cell);
    }

    await _store.write(
      copyStoredScanSnapshot(
        snapshot,
        cells: existing.values.toList(growable: false),
      ),
    );
  }

  @override
  Future<void> replaceAll(List<FolderCell> cells) async {
    final snapshot = await _store.read();
    await _store.write(
      copyStoredScanSnapshot(
        snapshot,
        cells: cells.map(folderCellToJson).toList(growable: false),
      ),
    );
  }
}
