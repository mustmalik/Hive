import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter_v1/application/models/scan_scope.dart';
import 'package:hive_flutter_v1/data/services/photo_manager_media_library_service.dart';
import 'package:hive_flutter_v1/domain/entities/media_asset.dart';
import 'package:photo_manager/photo_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.fluttercandies/photo_manager');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'limited scope resolves the limited root path instead of global library fetches',
    () async {
      final calls = <MethodCall>[];
      final logs = <String>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);

            switch (call.method) {
              case 'getPermissionState':
                return PermissionState.limited.index;
              case 'getAssetPathList':
                return {
                  'data': [
                    _pathMap(
                      id: 'limited_root',
                      name: 'Limited Library',
                      assetCount: 2,
                      isAll: true,
                    ),
                  ],
                };
              case 'fetchPathProperties':
                final id = (call.arguments as Map)['id'] as String;
                return {
                  'data': [
                    _pathMap(
                      id: id,
                      name: 'Limited Library',
                      assetCount: 2,
                      isAll: true,
                    ),
                  ],
                };
              case 'getAssetCountFromPath':
                final id = (call.arguments as Map)['id'] as String;
                return id == 'limited_root' ? 2 : 0;
              case 'getAssetListPaged':
                final id = (call.arguments as Map)['id'] as String;
                if (id != 'limited_root') {
                  return {'data': const []};
                }
                return {
                  'data': [
                    _assetMap(id: 'limited_1', title: 'IMG_LIMITED_1.HEIC'),
                    _assetMap(id: 'limited_2', title: 'IMG_LIMITED_2.HEIC'),
                  ],
                };
              case 'getAssetCount':
                return 99;
              case 'getAssetsByRange':
                return {
                  'data': [
                    _assetMap(id: 'all_1', title: 'IMG_ALL_1.HEIC'),
                    _assetMap(id: 'all_2', title: 'IMG_ALL_2.HEIC'),
                    _assetMap(id: 'all_3', title: 'IMG_ALL_3.HEIC'),
                  ],
                };
            }

            return null;
          });

      final service = PhotoManagerMediaLibraryService(debugLog: logs.add);

      final count = await service.getEstimatedAssetCount(
        scope: const ScanScope.limitedPhotos(),
      );
      final assets = await service.fetchAssets(
        scope: const ScanScope.limitedPhotos(),
        page: 0,
        pageSize: 10,
      );

      expect(count, 2);
      expect(assets.map((asset) => asset.id), ['limited_1', 'limited_2']);
      expect(
        calls.where((call) => call.method == 'getAssetPathList').length,
        greaterThanOrEqualTo(1),
      );
      expect(
        calls.any(
          (call) =>
              call.method == 'getAssetListPaged' &&
              (call.arguments as Map)['id'] == 'limited_root',
        ),
        isTrue,
      );
      expect(calls.any((call) => call.method == 'getAssetCount'), isFalse);
      expect(calls.any((call) => call.method == 'getAssetsByRange'), isFalse);
      expect(
        logs.any(
          (entry) =>
              entry.contains('scope=limited_library') &&
              entry.contains('path=limited_root'),
        ),
        isTrue,
      );
    },
  );

  test('all photos scope keeps using the global library fetch path', () async {
    final calls = <MethodCall>[];
    final logs = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);

          switch (call.method) {
            case 'getPermissionState':
              return PermissionState.authorized.index;
            case 'getAssetCount':
              return 3;
            case 'getAssetsByRange':
              return {
                'data': [
                  _assetMap(id: 'all_1', title: 'IMG_ALL_1.HEIC'),
                  _assetMap(id: 'all_2', title: 'IMG_ALL_2.HEIC'),
                  _assetMap(id: 'all_3', title: 'IMG_ALL_3.HEIC'),
                ],
              };
          }

          return null;
        });

    final service = PhotoManagerMediaLibraryService(debugLog: logs.add);

    final count = await service.getEstimatedAssetCount();
    final assets = await service.fetchAssets(page: 0, pageSize: 10);

    expect(count, 3);
    expect(assets.map((asset) => asset.id), ['all_1', 'all_2', 'all_3']);
    expect(calls.any((call) => call.method == 'getAssetCount'), isTrue);
    expect(calls.any((call) => call.method == 'getAssetsByRange'), isTrue);
    expect(calls.any((call) => call.method == 'getAssetPathList'), isFalse);
    expect(calls.any((call) => call.method == 'getAssetListPaged'), isFalse);
    expect(
      logs.any(
        (entry) =>
            entry.contains('scope=full_library') &&
            entry.contains('path=global_library'),
      ),
      isTrue,
    );
  });

  test('selected album scope uses the scoped album fetch path', () async {
    final calls = <MethodCall>[];
    final logs = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);

          switch (call.method) {
            case 'getPermissionState':
              return PermissionState.authorized.index;
            case 'fetchPathProperties':
              final id = (call.arguments as Map)['id'] as String;
              return {
                'data': [
                  _pathMap(
                    id: id,
                    name: 'Summer Roll',
                    assetCount: 4,
                    isAll: false,
                  ),
                ],
              };
            case 'getAssetCountFromPath':
              return 4;
            case 'getAssetListPaged':
              final id = (call.arguments as Map)['id'] as String;
              if (id != 'album_summer') {
                return {'data': const []};
              }
              return {
                'data': [
                  _assetMap(id: 'album_1', title: 'IMG_SUMMER_1.HEIC'),
                  _assetMap(id: 'album_2', title: 'IMG_SUMMER_2.HEIC'),
                ],
              };
            case 'getAssetListRange':
              final id = (call.arguments as Map)['id'] as String;
              if (id != 'album_summer') {
                return {'data': const []};
              }
              return {
                'data': [
                  _assetMap(id: 'album_1', title: 'IMG_SUMMER_1.HEIC'),
                  _assetMap(id: 'album_2', title: 'IMG_SUMMER_2.HEIC'),
                ],
              };
          }

          return null;
        });

    final service = PhotoManagerMediaLibraryService(debugLog: logs.add);
    const scope = ScanScope.album(
      albumId: 'album_summer',
      albumName: 'Summer Roll',
    );

    final count = await service.getEstimatedAssetCount(scope: scope);
    final assets = await service.fetchAssets(
      scope: scope,
      page: 0,
      pageSize: 2,
    );

    expect(count, 4);
    expect(assets.map((asset) => asset.id), ['album_1', 'album_2']);
    expect(
      calls.any(
        (call) =>
            call.method == 'fetchPathProperties' &&
            (call.arguments as Map)['id'] == 'album_summer',
      ),
      isTrue,
    );
    expect(
      calls.any(
        (call) =>
            call.method == 'getAssetListRange' &&
            (call.arguments as Map)['id'] == 'album_summer',
      ),
      isTrue,
    );
    expect(
      logs.any(
        (entry) =>
            entry.contains('scope=album') &&
            entry.contains('path=selected_album') &&
            entry.contains('albumId=album_summer'),
      ),
      isTrue,
    );
  });

  test(
    'fetchAlbums maps photo manager paths into PhotoAlbum metadata',
    () async {
      final logs = <String>[];
      final paths = {
        'album_empty': _pathMap(
          id: 'album_empty',
          name: 'Z Empty',
          assetCount: 0,
          isAll: false,
          darwinCollectionType: 1,
          darwinCollectionSubtype: 2,
        ),
        'album_favorites': _pathMap(
          id: 'album_favorites',
          name: 'Favorites',
          assetCount: 4,
          isAll: false,
          darwinCollectionType: 2,
          darwinCollectionSubtype: 203,
        ),
        'album_morocco': _pathMap(
          id: 'album_morocco',
          name: 'Morocco Trip',
          assetCount: 6,
          isAll: false,
          darwinCollectionType: 1,
          darwinCollectionSubtype: 2,
        ),
      };

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'getPermissionState':
                return PermissionState.authorized.index;
              case 'getAssetPathList':
                return {
                  'data': [
                    paths['album_empty'],
                    paths['album_favorites'],
                    paths['album_morocco'],
                  ],
                };
              case 'fetchPathProperties':
                final id = (call.arguments as Map)['id'] as String;
                return {
                  'data': [paths[id]],
                };
              case 'getAssetCountFromPath':
                final id = (call.arguments as Map)['id'] as String;
                return paths[id]?['assetCount'] ?? 0;
            }

            return null;
          });

      final service = PhotoManagerMediaLibraryService(debugLog: logs.add);

      final albums = await service.fetchAlbums(limit: 10);
      final favorites = albums.singleWhere(
        (album) => album.id == 'album_favorites',
      );
      final morocco = albums.singleWhere(
        (album) => album.id == 'album_morocco',
      );
      expect(albums.map((album) => album.title), ['Favorites', 'Morocco Trip']);
      expect(favorites.isSmartAlbum, isTrue);
      expect(favorites.isUserAlbum, isFalse);
      expect(favorites.subtype, 'smartAlbumFavorites');
      expect(morocco.isSmartAlbum, isFalse);
      expect(morocco.isUserAlbum, isTrue);
      expect(morocco.subtype, 'albumRegular');
      expect(albums.any((album) => album.id == 'album_empty'), isFalse);
      expect(
        logs.any((entry) => entry.contains('[HIVE-ALBUM] discovered albums=2')),
        isTrue,
      );
    },
  );

  test('maps screenshot subtype metadata to screenshot assets', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getPermissionState':
              return PermissionState.authorized.index;
            case 'getAssetsByRange':
              return {
                'data': [
                  _assetMap(
                    id: 'screen_1',
                    title: 'IMG_1234.PNG',
                    subtype: 1 << 2,
                  ),
                ],
              };
          }

          return null;
        });

    final service = PhotoManagerMediaLibraryService();
    final assets = await service.fetchAssets(page: 0, pageSize: 1);

    expect(assets, hasLength(1));
    expect(assets.single.type, MediaAssetType.screenshot);
  });
}

Map<String, dynamic> _pathMap({
  required String id,
  required String name,
  required int assetCount,
  required bool isAll,
  int albumType = 1,
  int darwinCollectionType = 1,
  int darwinCollectionSubtype = 2,
}) {
  return {
    'id': id,
    'name': name,
    'assetCount': assetCount,
    'isAll': isAll,
    'albumType': albumType,
    'darwinAssetCollectionType': darwinCollectionType,
    'darwinAssetCollectionSubtype': darwinCollectionSubtype,
  };
}

Map<String, dynamic> _assetMap({
  required String id,
  required String title,
  int subtype = 0,
}) {
  return {
    'id': id,
    'type': 1,
    'width': 1200,
    'height': 1600,
    'duration': 0,
    'orientation': 0,
    'title': title,
    'subtype': subtype,
    'createDt': 1713528000,
    'modifiedDt': 1713528000,
  };
}
