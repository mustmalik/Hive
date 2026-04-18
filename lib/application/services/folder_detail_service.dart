import '../models/folder_detail_snapshot.dart';

abstract interface class FolderDetailService {
  Future<FolderDetailSnapshot?> loadCell(String cellId);
}
