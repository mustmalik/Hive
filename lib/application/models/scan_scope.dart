enum ScanScopeType { fullLibrary, album }

enum ScanScopeKind { allPhotos, limitedPhotos, album }

class ScanScope {
  const ScanScope._({
    required this.type,
    required this.kind,
    required this.label,
    required this.description,
    this.albumId,
    this.albumTitle,
    this.isFolder = false,
  });

  const ScanScope.fullLibrary()
    : this._(
        type: ScanScopeType.fullLibrary,
        kind: ScanScopeKind.allPhotos,
        label: 'All Photos',
        description: 'Scan the full accessible library.',
      );

  const ScanScope.allPhotos() : this.fullLibrary();

  const ScanScope.limitedPhotos()
    : this._(
        type: ScanScopeType.fullLibrary,
        kind: ScanScopeKind.limitedPhotos,
        label: 'Limited-Access Photos',
        description: 'Scan only the photos currently available to HIVE.',
      );

  const ScanScope.album({
    required String albumId,
    String albumTitle = '',
    String albumName = '',
    this.isFolder = false,
  }) : assert(albumId.length > 0, 'Album scope requires an album id.'),
       assert(
         albumTitle.length > 0 || albumName.length > 0,
         'Album scope requires an album title.',
       ),
       type = ScanScopeType.album,
       kind = ScanScopeKind.album,
       label = albumTitle == '' ? albumName : albumTitle,
       description = 'Scan one selected ${isFolder ? 'folder' : 'album'}.',
       // Keep albumId non-nullable at the API boundary while the shared model
       // field remains nullable for full-library scopes.
       // ignore: prefer_initializing_formals
       albumId = albumId,
       albumTitle = albumTitle == '' ? albumName : albumTitle;

  final ScanScopeType type;
  final ScanScopeKind kind;
  final String label;
  final String description;
  final String? albumId;
  final String? albumTitle;
  final bool isFolder;

  bool get isAlbumSelection => kind == ScanScopeKind.album;

  String get logName {
    return switch (kind) {
      ScanScopeKind.allPhotos => 'full_library',
      ScanScopeKind.limitedPhotos => 'limited_library',
      ScanScopeKind.album => 'album',
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'kind': kind.name,
      'label': label,
      'description': description,
      'albumId': albumId,
      'albumTitle': albumTitle,
      'isFolder': isFolder,
    };
  }

  static ScanScope? fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }

    final kind = _kindFromJson(json);
    if (kind == null) {
      return null;
    }

    switch (kind) {
      case ScanScopeKind.allPhotos:
        return const ScanScope.fullLibrary();
      case ScanScopeKind.limitedPhotos:
        return const ScanScope.limitedPhotos();
      case ScanScopeKind.album:
        final albumId = json['albumId'];
        final albumTitle = json['albumTitle'] ?? json['label'];
        if (albumId is! String ||
            albumId.isEmpty ||
            albumTitle is! String ||
            albumTitle.isEmpty) {
          return null;
        }

        return ScanScope.album(
          albumId: albumId,
          albumTitle: albumTitle,
          isFolder: json['isFolder'] == true,
        );
    }
  }

  static ScanScopeKind? _kindFromJson(Map<String, dynamic> json) {
    final kindName = json['kind'];
    if (kindName is String) {
      final matches = ScanScopeKind.values.where(
        (value) => value.name == kindName,
      );
      if (matches.isNotEmpty) {
        return matches.first;
      }
    }

    final typeName = json['type'];
    if (typeName == ScanScopeType.fullLibrary.name) {
      return ScanScopeKind.allPhotos;
    }
    if (typeName == ScanScopeType.album.name) {
      return ScanScopeKind.album;
    }

    return null;
  }
}

class ScanRequest {
  const ScanRequest({this.scope = const ScanScope.fullLibrary()});

  final ScanScope scope;

  ScanScopeType get type => scope.type;

  String? get albumId => scope.albumId;

  String? get albumTitle => scope.albumTitle;
}
