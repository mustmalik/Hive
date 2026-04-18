enum FolderCellOrigin { manual, suggested, hybrid }

class FolderCell {
  const FolderCell({
    required this.id,
    required this.name,
    required this.origin,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.coverAssetId,
    this.labelIds = const [],
    this.assetIds = const [],
    this.isPinned = false,
  });

  final String id;
  final String name;
  final FolderCellOrigin origin;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final String? coverAssetId;
  final List<String> labelIds;
  final List<String> assetIds;
  final bool isPinned;

  int get assetCount => assetIds.length;
}
