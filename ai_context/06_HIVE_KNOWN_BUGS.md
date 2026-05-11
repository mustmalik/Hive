# HIVE — Known Bugs

Keep this file short and current. Prefer 5–15 lines per bug. Paste only the *relevant* logs.

## Bug 1: “Family” category drift / inconsistent taxonomy

### Symptom
The UI and some scan display mappings reference a `family` cell, but placement logic routes family cues into `people`.

### Expected
Either:
- `family` is a real supported cell with placement logic and persistence semantics, **or**
- `family` is removed/hidden everywhere and fully treated as `people`.

### Actual
`family` exists in UI lists and scan coordinator display names, but mapping tests assert “former family cues into People”.

### Suspected files
- `lib/application/models/hive_cell_category.dart`
- `lib/data/services/real_scan_coordinator.dart`
- `lib/data/services/persisted_home_dashboard_service.dart` (preview content includes “Family”)
- `lib/data/services/placement/placement_definitions.dart` (no `family` rule)
- `test/keyword_folder_mapping_service_test.dart`

### Status
Open

---

## Bug 2: Placement audit entries lack real debug payload

### Symptom
`PlacementAuditEntry` is used as an authoritative “final cell” source for dashboard/folder membership reconciliation, but persisted entries do not include real scores/vetoes/gates/signals.

### Expected
Audit entries should (at minimum) preserve enough detail to debug why an asset landed somewhere (top scores, fired vetoes/gates, key derived signal values).

### Actual
Scan persistence writes audit entries with empty `topScores`, empty `firedVetoes`/`firedGates`, and zeroed signal values.

### Suspected files
- `lib/data/services/real_scan_coordinator.dart` (`_persistResults()`)
- `lib/application/models/placement_audit_entry.dart`
- `lib/data/services/persisted_home_dashboard_service.dart`
- `lib/data/services/persisted_folder_detail_service.dart`

### Status
Open

---

## Bug 3: Structural extraction variance can cause scan vs mapping placement mismatch

### Symptom
A “scan pass” provisional placement can differ from the final mapping pass, especially for structural-driven meme/doc cases (OCR/layout dependent).

### Expected
Placements should be stable within a scan run and when reloading the dashboard.

### Actual
There are explicit debug logs for pass mismatches; the system primes structural signals and caches by asset id to reduce drift, but timeouts/failures can still change outcomes.

### Suspected files
- `lib/data/services/placement/keyword_placement_pipeline.dart` (`PlacementAnalysisBuilder` caching/timeout)
- `lib/data/services/structural_signal_extractor.dart`
- `lib/data/services/real_scan_coordinator.dart` (priming + pass compare)

### Status
Open / needs more field evidence

