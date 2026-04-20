class MediaAlbum {
  const MediaAlbum({
    required this.id,
    required this.name,
    required this.assetCount,
    this.isAll = false,
    this.isFolder = false,
  });

  final String id;
  final String name;
  final int assetCount;
  final bool isAll;
  final bool isFolder;
}
