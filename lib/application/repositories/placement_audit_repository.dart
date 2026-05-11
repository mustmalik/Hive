import '../models/placement_audit_entry.dart';

abstract interface class PlacementAuditRepository {
  Future<void> saveEntry(PlacementAuditEntry entry);

  Future<List<PlacementAuditEntry>> getRecentAuditEntries(int limit);

  Future<void> clearAuditLog();
}
