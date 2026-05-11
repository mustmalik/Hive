class PhotoAlbum {
  const PhotoAlbum({
    required this.id,
    required this.title,
    required this.assetCount,
    required this.isSmartAlbum,
    required this.isUserAlbum,
    this.subtype,
    this.isAll = false,
    this.isFolder = false,
  });

  final String id;
  final String title;
  final int assetCount;
  final bool isSmartAlbum;
  final bool isUserAlbum;
  final String? subtype;
  final bool isAll;
  final bool isFolder;

  String get name => title;
}
