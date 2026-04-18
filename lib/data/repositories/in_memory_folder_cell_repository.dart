import '../../application/repositories/folder_cell_repository.dart';
import '../../domain/entities/folder_cell.dart';

class InMemoryFolderCellRepository implements FolderCellRepository {
  InMemoryFolderCellRepository({List<FolderCell>? seedCells})
    : _cells = List<FolderCell>.from(seedCells ?? _defaultCells());

  final List<FolderCell> _cells;

  factory InMemoryFolderCellRepository.seeded() {
    return InMemoryFolderCellRepository();
  }

  @override
  Future<void> clear() async {
    _cells.clear();
  }

  @override
  Future<List<FolderCell>> getAllCells() async {
    return List<FolderCell>.unmodifiable(_cells);
  }

  @override
  Future<FolderCell?> getCellById(String cellId) async {
    for (final cell in _cells) {
      if (cell.id == cellId) {
        return cell;
      }
    }

    return null;
  }

  @override
  Future<void> saveCells(List<FolderCell> cells) async {
    for (final cell in cells) {
      final index = _cells.indexWhere((existing) => existing.id == cell.id);

      if (index >= 0) {
        _cells[index] = cell;
      } else {
        _cells.add(cell);
      }
    }
  }

  static List<FolderCell> _defaultCells() {
    final now = DateTime.now();

    FolderCell buildCell({
      required String id,
      required String name,
      required int assetCount,
      required FolderCellOrigin origin,
      bool isPinned = false,
    }) {
      return FolderCell(
        id: id,
        name: name,
        origin: origin,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(hours: 6)),
        assetIds: List<String>.generate(assetCount, (index) => '${id}_$index'),
        isPinned: isPinned,
      );
    }

    return [
      buildCell(
        id: 'pets',
        name: 'Pets',
        assetCount: 128,
        origin: FolderCellOrigin.hybrid,
        isPinned: true,
      ),
      buildCell(
        id: 'travel',
        name: 'Travel',
        assetCount: 84,
        origin: FolderCellOrigin.suggested,
      ),
      buildCell(
        id: 'food',
        name: 'Food',
        assetCount: 62,
        origin: FolderCellOrigin.suggested,
      ),
      buildCell(
        id: 'basketball',
        name: 'Basketball',
        assetCount: 41,
        origin: FolderCellOrigin.manual,
        isPinned: true,
      ),
      buildCell(
        id: 'unsorted',
        name: 'Unsorted',
        assetCount: 214,
        origin: FolderCellOrigin.hybrid,
      ),
      buildCell(
        id: 'family',
        name: 'Family',
        assetCount: 73,
        origin: FolderCellOrigin.manual,
      ),
      buildCell(
        id: 'sunsets',
        name: 'Sunsets',
        assetCount: 27,
        origin: FolderCellOrigin.suggested,
      ),
      buildCell(
        id: 'workouts',
        name: 'Workouts',
        assetCount: 21,
        origin: FolderCellOrigin.manual,
      ),
      buildCell(
        id: 'weekends',
        name: 'Weekends',
        assetCount: 56,
        origin: FolderCellOrigin.suggested,
      ),
      buildCell(
        id: 'favorites',
        name: 'Favorites',
        assetCount: 33,
        origin: FolderCellOrigin.hybrid,
      ),
      buildCell(
        id: 'receipts',
        name: 'Receipts',
        assetCount: 18,
        origin: FolderCellOrigin.manual,
      ),
      buildCell(
        id: 'screenshots',
        name: 'Screenshots',
        assetCount: 44,
        origin: FolderCellOrigin.suggested,
      ),
    ];
  }
}
