# Cursor Prompt Template

You are working in the Hive Flutter/Dart project.

Project path:
`/Users/stafa/Desktop/Hive/hive_flutter_v1`

Your task:
[INSERT TASK]

## Rules (non-negotiable)

- Do not rewrite the architecture.
- Do not use cloud APIs.
- Do not retrain models.
- Do not move/rename/mutate Apple Photos assets.
- Keep changes minimal and deterministic.
- Add or update regression tests for every behavior change.
- Run:
  - `flutter analyze`
  - `flutter test`

## First inspect these files (must be explicit paths)

[INSERT FILES]

Common starting points for placement bugs:

- `lib/data/services/placement/keyword_placement_pipeline.dart`
- `lib/data/services/placement/placement_definitions.dart`
- `lib/data/services/placement/placement_models.dart`
- `lib/data/services/structural_signal_extractor.dart`
- `lib/data/services/keyword_folder_mapping_service.dart`
- `test/keyword_placement_pipeline_test.dart`
- `test/keyword_folder_mapping_service_test.dart`

If the bug is persistence/dashboard-related:

- `lib/data/services/persisted_home_dashboard_service.dart`
- `lib/data/services/persisted_folder_detail_service.dart`
- `lib/data/services/resolved_cell_membership.dart`
- `test/persistence_reconciliation_test.dart`
- `test/cell_membership_filtering_test.dart`

If the bug is scan or scope-related:

- `lib/data/services/real_scan_coordinator.dart`
- `lib/data/services/photo_manager_media_library_service.dart`
- `test/real_scan_coordinator_test.dart`

## Bug evidence

### Symptom
[INSERT DESCRIPTION]

### Logs (only relevant lines)
[INSERT LOGS]

### Example labels/signals (if available)
- asset type: [image/livePhoto/screenshot/video]
- top labels: [...]
- structural signals: faces/textCoverage/MRZ/chat/table/barcode/QR

## Expected behavior

[INSERT EXPECTED BEHAVIOR]

## Constraints / guardrails specific to this fix

[INSERT ANY EXTRA CONSTRAINTS]

## Required changes

- Make the smallest possible change in the correct stage:
  - routing (`ContentTypeRoutingStage`)
  - scoring (`WeightedCategoryScoringStage`)
  - precedence/veto (`VetoPrecedenceStage`)
  - gates (`CategoryEntryGateStage`)
  - decision thresholds/margins (`PlacementDecisionStage`)
- Add/adjust regression tests:
  - Prefer `test/keyword_placement_pipeline_test.dart` for stage-level behavior.
  - Prefer `test/keyword_folder_mapping_service_test.dart` for high-level mapping expectations.

## Validation commands

```bash
flutter analyze
flutter test
```

## After fixing, provide a final report

1. Root cause
2. Files changed
3. Exact logic changed (what and why)
4. Tests added/updated (and what they assert)
5. Validation results (`flutter analyze`, `flutter test`)
6. Any remaining risk / follow-ups

