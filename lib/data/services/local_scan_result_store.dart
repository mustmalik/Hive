import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalScanResultStore {
  LocalScanResultStore({
    Future<Directory> Function()? directoryProvider,
    this.fileName = 'hive_scan_results.json',
  }) : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;
  final String fileName;

  Future<void> _queue = Future<void>.value();

  Future<StoredScanSnapshot> read() async {
    return _serialize(() async {
      final file = await _resolveFile();
      if (!await file.exists()) {
        return const StoredScanSnapshot();
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return const StoredScanSnapshot();
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const StoredScanSnapshot();
      }

      return StoredScanSnapshot.fromJson(decoded);
    });
  }

  Future<void> write(StoredScanSnapshot snapshot) async {
    await _serialize(() async {
      final file = await _resolveFile();
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
        flush: true,
      );
    });
  }

  Future<T> update<T>(Future<T> Function(StoredScanSnapshot snapshot) action) {
    return _serialize(() async {
      final current = await read();
      final result = await action(current);
      await write(current);
      return result;
    });
  }

  Future<File> _resolveFile() async {
    final directory = await _directoryProvider();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return File('${directory.path}/$fileName');
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    final pending = _queue;

    _queue = pending.catchError((_) {}).then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });

    return completer.future;
  }
}

class StoredScanSnapshot {
  const StoredScanSnapshot({
    this.settings,
    this.cells = const <Map<String, dynamic>>[],
    this.assets = const <Map<String, dynamic>>[],
    this.classifications = const <Map<String, dynamic>>[],
    this.overrides = const <Map<String, dynamic>>[],
    this.runs = const <Map<String, dynamic>>[],
  });

  factory StoredScanSnapshot.fromJson(Map<String, dynamic> json) {
    return StoredScanSnapshot(
      settings: _readMap(json['settings']),
      cells: _readList(json['cells']),
      assets: _readList(json['assets']),
      classifications: _readList(json['classifications']),
      overrides: _readList(json['overrides']),
      runs: _readList(json['runs']),
    );
  }

  final Map<String, dynamic>? settings;
  final List<Map<String, dynamic>> cells;
  final List<Map<String, dynamic>> assets;
  final List<Map<String, dynamic>> classifications;
  final List<Map<String, dynamic>> overrides;
  final List<Map<String, dynamic>> runs;

  Map<String, dynamic> toJson() {
    return {
      'settings': settings,
      'cells': cells,
      'assets': assets,
      'classifications': classifications,
      'overrides': overrides,
      'runs': runs,
    };
  }

  static List<Map<String, dynamic>> _readList(Object? value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((entry) => entry.cast<String, dynamic>())
        .toList(growable: false);
  }

  static Map<String, dynamic>? _readMap(Object? value) {
    if (value is! Map) {
      return null;
    }

    return value.cast<String, dynamic>();
  }
}
