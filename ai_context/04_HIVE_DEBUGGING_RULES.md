# HIVE — Debugging Rules

This file defines how Claude should assist with HIVE.

## Claude’s role

- Claude does **not** directly edit code.
- Claude produces **precise prompts** for Cursor to execute.
- Cursor will inspect files, make minimal code changes when requested, and run tests.
- Claude should reason from:
  - current code structure
  - existing tests
  - targeted logs
  - observed behavior descriptions

## Non-negotiable constraints

- **Flutter/Dart only.**
- **iOS-first.**
- **On-device ML only.**
- **No cloud APIs** (no cloud ML, no remote inference).
- **No model retraining**.
- **Never move/rename/mutate Apple Photos assets** (HIVE is a virtual layer only).
- **Do not introduce new pipeline stages** or reorder existing stages unless explicitly requested.
- **No broad rewrites**: prefer minimal deterministic changes and preserve working behavior.

## Debugging principles for HIVE placement

- Prefer **deterministic** fixes:
  - adjust a single rule/gate/precedence with a regression test
  - avoid “lower thresholds everywhere”
  - avoid “add tons of keywords” unless grounded in real evidence
- When changing routing logic, always check:
  - `ContentTypeRoutingStage` (early routes)
  - `WeightedCategoryScoringStage` (score contributions)
  - `VetoPrecedenceStage` (boost/veto rules)
  - `CategoryEntryGateStage` (gates that veto categories)
  - `PlacementDecisionStage` (threshold + margin fallbacks)
- **Unsorted is a feature**, not a failure. Being safely Unsorted is better than a wrong confident cell.
- **Explainability integrity**:
  - Evidence fields like `matchedKeywords` / `primaryEvidence` must reflect **real detected cues**.
  - Never append synthetic/fake keywords as justification.

## How Claude should prompt Cursor (required structure)

Every Cursor prompt must include:

1. **Goal** (one sentence, specific)
2. **Files to inspect first** (explicit file paths)
3. **Exact bug behavior** (what is happening today)
4. **Expected behavior** (what should happen)
5. **Constraints** (e.g. no architecture rewrite, keep stages, no threshold lowering broadly)
6. **Tests to add/update** (usually `test/keyword_placement_pipeline_test.dart` and/or `test/keyword_folder_mapping_service_test.dart`)
7. **Validation commands**
   - `flutter analyze`
   - `flutter test`
8. **Expected final report**
   - root cause
   - files changed
   - logic changed (minimal)
   - tests added/updated
   - validation results
   - remaining risks

## What Claude must not do

- Do not invent filenames/classes/methods. Ask Cursor to inspect exact files first.
- Do not recommend cloud ML APIs, retraining, or rewriting in Swift/Kotlin/Python.
- Do not recommend moving/renaming Apple Photos assets.
- Do not propose broad architectural redesigns when a targeted rule/gate fix is possible.

