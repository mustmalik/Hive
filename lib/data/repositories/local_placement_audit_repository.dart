import 'dart:async';

import '../../application/models/placement_audit_entry.dart';
import '../../application/repositories/placement_audit_repository.dart';
import '../services/local_scan_result_store.dart';
import 'local_scan_storage_codec.dart';

class LocalPlacementAuditRepository implements PlacementAuditRepository {
  LocalPlacementAuditRepository({required LocalScanResultStore store})
    : _store = store;

  final LocalScanResultStore _store;
  Future<void> _queue = Future<void>.value();

  @override
  Future<void> clearAuditLog() async {
    await _serialize(() async {
      final snapshot = await _store.read();
      await _store.write(copyStoredScanSnapshot(snapshot, audits: const []));
    });
  }

  @override
  Future<List<PlacementAuditEntry>> getRecentAuditEntries(int limit) async {
    final snapshot = await _store.read();
    return snapshot.audits
        .map(placementAuditEntryFromJson)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<void> saveEntry(PlacementAuditEntry entry) async {
    await _serialize(() async {
      final snapshot = await _store.read();
      final current = snapshot.audits
          .map(placementAuditEntryFromJson)
          .take(500)
          .toList(growable: false);
      final next = <PlacementAuditEntry>[entry, ...current];
      await _store.write(
        copyStoredScanSnapshot(
          snapshot,
          audits: next.map(placementAuditEntryToJson).toList(growable: false),
        ),
      );
    });
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final completer = Completer<void>();
    final pending = _queue;

    _queue = pending.catchError((_) {}).then((_) async {
      try {
        await operation();
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });

    return completer.future;
  }
}
