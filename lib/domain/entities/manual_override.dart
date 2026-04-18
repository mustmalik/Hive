enum ManualOverrideAction {
  includeInCell,
  excludeFromCell,
  promoteLabel,
  suppressLabel,
}

class ManualOverride {
  const ManualOverride({
    required this.id,
    required this.assetId,
    required this.action,
    required this.createdAt,
    this.cellId,
    this.labelId,
    this.note,
  });

  final String id;
  final String assetId;
  final ManualOverrideAction action;
  final DateTime createdAt;
  final String? cellId;
  final String? labelId;
  final String? note;
}
