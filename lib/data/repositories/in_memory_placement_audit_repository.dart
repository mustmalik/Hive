import '../../application/models/placement_audit_entry.dart';
import '../../application/repositories/placement_audit_repository.dart';

class InMemoryPlacementAuditRepository implements PlacementAuditRepository {
  InMemoryPlacementAuditRepository({List<PlacementAuditEntry>? seedEntries})
    : _entries = List<PlacementAuditEntry>.from(seedEntries ?? const []);

  final List<PlacementAuditEntry> _entries;

  @override
  Future<void> clearAuditLog() async {
    _entries.clear();
  }

  @override
  Future<List<PlacementAuditEntry>> getRecentAuditEntries(int limit) async {
    return List<PlacementAuditEntry>.unmodifiable(_entries.take(limit));
  }

  @override
  Future<void> saveEntry(PlacementAuditEntry entry) async {
    _entries.insert(0, entry);
  }
}
