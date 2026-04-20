enum ScanScopeKind { allPhotos, limitedPhotos, album }

class ScanScope {
  const ScanScope._({
    required this.kind,
    required this.label,
    required this.description,
    this.albumId,
    this.isFolder = false,
  });

  const ScanScope.allPhotos()
    : this._(
        kind: ScanScopeKind.allPhotos,
        label: 'All Photos',
        description: 'Scan the full accessible library.',
      );

  const ScanScope.limitedPhotos()
    : this._(
        kind: ScanScopeKind.limitedPhotos,
        label: 'Limited-Access Photos',
        description: 'Scan only the photos currently available to HIVE.',
      );

  const ScanScope.album({
    required String albumId,
    required String albumName,
    bool isFolder = false,
  }) : this._(
         kind: ScanScopeKind.album,
         label: albumName,
         description: 'Scan one selected ${isFolder ? 'folder' : 'album'}.',
         albumId: albumId,
         isFolder: isFolder,
       );

  final ScanScopeKind kind;
  final String label;
  final String description;
  final String? albumId;
  final bool isFolder;

  bool get isAlbumSelection => kind == ScanScopeKind.album;
}
