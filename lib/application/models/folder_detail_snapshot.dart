import 'folder_detail_item.dart';

class FolderDetailSnapshot {
  const FolderDetailSnapshot({
    required this.cellId,
    required this.cellName,
    required this.description,
    required this.totalCount,
    required this.items,
  });

  final String cellId;
  final String cellName;
  final String description;
  final int totalCount;
  final List<FolderDetailItem> items;
}
