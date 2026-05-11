import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter_v1/application/models/scan_scope.dart';

void main() {
  test('full library scope uses the Phase 1 fullLibrary type', () {
    const scope = ScanScope.fullLibrary();

    expect(scope.type, ScanScopeType.fullLibrary);
    expect(scope.albumId, isNull);
    expect(scope.albumTitle, isNull);
    expect(scope.logName, 'full_library');
  });

  test('album scope requires a selected album id and title', () {
    expect(
      () => ScanScope.album(albumId: '', albumTitle: 'Morocco Trip'),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => ScanScope.album(albumId: 'album_morocco'),
      throwsA(isA<AssertionError>()),
    );
    expect(
      ScanScope.fromJson({
        'type': ScanScopeType.album.name,
        'albumTitle': 'Morocco Trip',
      }),
      isNull,
    );
  });

  test('album scope stores album metadata outside asset analysis', () {
    const scope = ScanScope.album(
      albumId: 'album_morocco',
      albumTitle: 'Morocco Trip',
    );

    expect(scope.type, ScanScopeType.album);
    expect(scope.albumId, 'album_morocco');
    expect(scope.albumTitle, 'Morocco Trip');
    expect(scope.label, 'Morocco Trip');
    expect(scope.logName, 'album');
  });
}
