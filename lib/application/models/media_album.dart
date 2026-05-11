import 'photo_album.dart';

export 'photo_album.dart';

class MediaAlbum extends PhotoAlbum {
  const MediaAlbum({
    required super.id,
    required String name,
    required super.assetCount,
    super.isAll = false,
    super.isFolder = false,
    super.isSmartAlbum = false,
    bool isUserAlbum = true,
    super.subtype,
  }) : super(title: name, isUserAlbum: isFolder || isAll ? false : isUserAlbum);

  MediaAlbum.fromPhotoAlbum(PhotoAlbum album)
    : this(
        id: album.id,
        name: album.title,
        assetCount: album.assetCount,
        isAll: album.isAll,
        isFolder: album.isFolder,
        isSmartAlbum: album.isSmartAlbum,
        isUserAlbum: album.isUserAlbum,
        subtype: album.subtype,
      );
}
