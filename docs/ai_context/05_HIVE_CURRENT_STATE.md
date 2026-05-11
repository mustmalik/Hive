# HIVE — Current State

This file should be updated as the app changes. It describes what exists **right now** in the repo.

## Current development phase

HIVE is a **working MVP**: the app can request Photos permission, scan a chosen scope, run on-device labeling + structural extraction, assign assets to cells via a multi-stage placement pipeline, and display results on a dashboard and per-cell detail screens.

It is **not production-ready** yet due to taxonomy inconsistencies and the complexity/risk of heuristic drift.

## Currently implemented (high signal)

- **Permission + onboarding flow**
  - `SplashScreen` routes: onboarding → permission → home.
  - Supports limited Photos access and managing limited selection.

- **Scan scopes**
  - Full library, limited library, selected album/folder.
  - Album picker UI in `HomeScreen`.

- **On-device labeling backends**
  - Apple Vision via `MethodChannel` (`IosVisionClassificationService`).
  - Google ML Kit plugin backend (`GoogleMlKitClassificationService`).

- **Structural signal extraction**
  - Face count + face area ratio
  - OCR text + coverage ratio + layout heuristics (chat/table)
  - Barcode/QR detection
  - MRZ pattern detection (passport/id)

- **Placement pipeline**
  - Stages: analysis builder → content routing → weighted scoring → veto/precedence → gates → decision.
  - Deterministic routing for key cases (videos, strong screenshots, mosque/architecture places, etc).
  - Strong guardrails: memes vs people, illustrated content vs people, device screens vs people, identity docs vs people.
  - Unsorted fallback with explicit reasons (no signal, low confidence, narrow margin).

- **Persistence + reconciliation**
  - Local JSON snapshot store (`LocalScanResultStore`).
  - Dashboard and cell detail compute **authoritative membership** per asset using:
    1) manual overrides
    2) audit final cell
    3) placement mapping

- **Regression tests**
  - Extensive placement regression suite: `test/keyword_placement_pipeline_test.dart`.
  - Higher-level mapping tests: `test/keyword_folder_mapping_service_test.dart`.
  - Persistence reconciliation tests: `test/persistence_reconciliation_test.dart`, `test/cell_membership_filtering_test.dart`.
  - Scan coordinator tests: `test/real_scan_coordinator_test.dart`.

## Current cells (effective)

Placement rule targets (cell IDs):

`people`, `pets`, `food`, `places`, `nature`, `travel`, `vehicles`, `sports`, `screenshots`, `devices_tech`, `documents_receipts`, `receipts`, `books`, `animation`, `memes`, `videos`, `unsorted`

## Current concerns / risk areas

- **Taxonomy drift**: `Family` still appears in UI models and scan coordinator display maps, but placement maps family cues into `people`.
- **Memes vs People**: many edge-case rules exist; easy to regress without targeted tests.
- **Screenshots vs Documents**: text-heavy UI vs document-like signals remains a frequent conflict zone.
- **Places vs People**: “incidental people” handling for landmarks is subtle and sensitive.
- **Structural determinism**: structural extraction timeouts/failures can change routing; the app tries to mitigate via caching + priming.
- **Audit explainability gap**: persisted `PlacementAuditEntry` written at scan completion currently stores minimal debug payload (scores/vetoes not populated), limiting post-hoc debugging.

## Validation commands

```bash
flutter analyze
flutter test
```

