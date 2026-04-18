import '../../domain/entities/folder_cell.dart';

abstract interface class FolderCellRepository {
  Future<void> saveCells(List<FolderCell> cells);

  Future<List<FolderCell>> getAllCells();

  Future<FolderCell?> getCellById(String cellId);

  Future<void> clear();
}
