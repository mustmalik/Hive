# HIVE — Debugging Playbook

Operational guide for Claude → Cursor placement debugging. Aligns with `04_HIVE_DEBUGGING_RULES.md` and `07_CURSOR_PROMPT_TEMPLATE.md`. **Claude does not edit Dart; Cursor does**, after evidence-backed prompts.

---

## 1. Purpose

- Narrow **placement bugs** (wrong cell, scan vs UI mismatch, unstable category) to the **correct pipeline stage** before any code change.
- Reduce regressions by targeting **one stage, one rule, one test** when possible.
- Preserve **sync/async** and **legacy ID** invariants documented below.

---

## 2. Pre-Cursor diagnostic checklist

Before writing a Cursor prompt, collect:

- [ ] **Asset**: `MediaAsset.id`, `MediaAssetType` (image / video / screenshot / …).
- [ ] **Observed cell** vs **expected cell** (use placement `cellId` strings, not display names only).
- [ ] **Top Vision labels** (or test fixture labels) and approximate confidences.
- [ ] **Repro path**: scan only, home dashboard, folder detail, reclassification service, tests.
- [ ] **Logs** (if available): `[HIVE-ROUTE-*]`, `[HIVE-PRECEDENCE]`, `[HIVE-GATE]`, `[HIVE-DECISION]`, `[HIVE-SCENE]`, `[HIVE-FOOD]`, `[HIVE-SCAN]`, `[HIVE-PASS-MISMATCH]` from `lib/data/services/real_scan_coordinator.dart`.
- [ ] **Overrides / audit**: manual override? `PlacementAuditEntry`? (see `lib/data/services/resolved_cell_membership.dart`, persisted services.)
- [ ] **Whether structural ML ran**: async path runs `StructuralSignalExtractor`; sync default uses empty structural signals in `PlacementAnalysisBuilder.build`.

---

## 3. Decision tree — owning stage

Flow in `KeywordPlacementPipeline._explainFromAnalysis` (`lib/data/services/placement/keyword_placement_pipeline.dart`):

1. **`ContentTypeRoutingStage.route`** — If it returns non-null, **pipeline ends** (no scoring). Suspect: videos, screenshots, receipts, strong early heuristics.
2. **Empty `topLabels`** → immediate **unsorted** (`noSignal`).
3. **`WeightedCategoryScoringStage.score`** — Baseline scores from `KeywordPlacementDefinitions.rules` (videos excluded from scoring list).
4. **`VetoPrecedenceStage.apply`** — `_applyDeterministicPrecedenceRules` then `_applyAbsurdJumpSafeguards`.
5. **Natural photo penalty** — If `!isNaturalPhoto(...)`, subtracts from selected cells (see §5).
6. **`CategoryEntryGateStage.apply`** — Per-cell `vetoed` + reason string.
7. **`PlacementDecisionStage.resolve`** — Margins, confidence thresholds, unsorted fallbacks.

**Heuristics**

- Wrong cell but **same “family” of mistake** (e.g. screenshot vs meme): start at **routing** or **veto**, then **gates**.
- **Unsorted** when user expected a cell: often **decision stage** or **gate**; check runner-up margin messages in explanation.
- **Dashboard count ≠ folder after scan**: check **§9** before changing rules.

---

## 4. High-risk modification zones

| Zone | Path | Risk |
|------|------|------|
| Deterministic precedence | `VetoPrecedenceStage._applyDeterministicPrecedenceRules` in `keyword_placement_pipeline.dart` | Long ordered branches, **multiple early `return`s**; reordering changes global winners. |
| Routing | `ContentTypeRoutingStage` in same file | Short-circuits entire pipeline. |
| Threshold constants | `lib/data/services/placement/placement_definitions.dart` | Broad threshold edits affect many assets. |
| Natural photo | `isNaturalPhoto` + closure `applyNaturalPhotoPenalty` in `keyword_placement_pipeline.dart` | Large score swing (−40) after precedence. |
| Legacy cell scoring | Same file: boosts/vetoes for `animation_cartoon_meme` | Diverges from UI normalization to `memes` (see §10). |

Prefer **one branch**, **one gate**, or **one test** per change set.

---

## 5. Natural photo penalty risks

- **Definition**: top-level `isNaturalPhoto(AssetAnalysis, DerivedSignals)` in `keyword_placement_pipeline.dart` (~8098+). Uses `structural` (meme/poster, chat, document-like), `derived.graphicnessScore` / `uiDensityScore`, cue strengths, scenic bypass logic.
- **Penalty**: local `applyNaturalPhotoPenalty` inside `_explainFromAnalysis` (~2599+): **−40** on `people`, `pets`, `food`, `sports`, `travel`, `places`, `nature` when not natural.
- **Exceptions**: food (dining rescue + tiny face; packaging deferral); people (`keepPeopleForPrimarySubject` / people-first + guards).
- **Order**: Applied **after** `VetoPrecedenceStage`, **before** `CategoryEntryGateStage`.

**Risk**: Assets that are real photos but structurally “document/UI/graphic heavy” get hammered late; gates may then kill the intended cell.

---

## 6. Veto precedence risks

- **Class**: `VetoPrecedenceStage` in `keyword_placement_pipeline.dart`.
- **Early returns** in `_applyDeterministicPrecedenceRules` (skip rest of method): strong **physical book** block; **non-photographic artwork**; **confirmed meme subtype**; **caption overlay meme moderate** (exact conditions in file).
- **Memes cell**: boosted and other cells vetoed; **grep shows no `_vetoRule` for `memes`** in this stage — rejection usually via **gate**.
- **Animation cell**: `_vetoRule` for `animation` appears in **physical book** branch among others.
- Many branches use **`_penalizeRule`** vs **`_vetoRule`** — different downstream behavior in decision stage.

**Risk**: Adding a branch without checking **early returns** below it silently stops firing later logic.

---

## 7. Absurd jump safeguard risks

- **Method**: `_applyAbsurdJumpSafeguards` in `VetoPrecedenceStage`, same file (~6123+).
- **Role**: Anti-drift — natural scene vs screenshot/graphic legacy cell, weak pets, weak sports, weak documents, places vs screen presentation, travel vs scenery, food vs document strength, etc.
- **Cells touched**: includes **`screenshots`**, **`animation_cartoon_meme`**, **`pets`**, **`sports`**, **`documents_receipts`**, **`places`**, **`travel`**, plus **`_penalizeRule`** on `documents_receipts`, `food`, `places`, `sports`.

**Risk**: Fixes for one drift class (e.g. places) can re-open another (pets, screenshots).

---

## 8. Category gate risks

- **Class**: `CategoryEntryGateStage` in `keyword_placement_pipeline.dart` (~6428+).
- Dispatch on `score.rule.cellId`; skipped if already `vetoed`.
- **Explicit numeric thresholds** appear in several `_reject*` methods (e.g. people `score >= 0.5`, food `score >= 0.58`, places `score >= 0.72` with keyword floor **0.52**) — treat as contracts; changing them needs regression tests.
- **`animation`** and **`animation_cartoon_meme`** share **`_rejectAnimationCartoonMeme`**.
- **`memes`** gate requires overlay/meme structure (`_rejectMemes`).

**Risk**: Gate failure strings (`'… gate …'`) are user-debuggable; keep messages truthful when adjusting logic.

---

## 9. Sync vs async placement mismatch risks

| API | Builder | Typical structural |
|-----|---------|-------------------|
| `KeywordPlacementPipeline.explainPlacement` | `PlacementAnalysisBuilder.build` | Default **empty** structural unless injected |
| `explainPlacementAsync` | `buildAsync` → `_resolveStructuralSignals` | **Extractor** + 3s timeout; failures → empty |

**Call sites (verify when debugging)**

- **Async**: `KeywordFolderMappingService.buildSuggestedCells` → `explainPlacementAsync` per asset (`lib/data/services/keyword_folder_mapping_service.dart`).
- **Sync**: `resolveCellIdForAsset` / `resolveCellExplanationForAsset` (`lib/data/services/resolved_cell_membership.dart`); scan **progress** placement (`RealScanCoordinator._resolvePlacementForProgress`); `PersistedAssetReclassificationService`.
- **Async on reload**: `PersistedFolderDetailService` when mapping service is `KeywordFolderMappingService` (comment: structural meme stability).

**Risk**: Same labels can yield **different cells** if structural signals differ. Suspect mismatch when **persisted scan** (async grouping) disagrees with **dashboard** (sync resolve) or **scan progress** (sync).

---

## 10. Legacy category ID risks

- **Rules** include **`animation`**, **`memes`**, and legacy **`animation_cartoon_meme`** (`lib/data/services/placement/placement_definitions.dart`).
- **UI / membership normalization**: `animation_cartoon_meme` → **`memes`** in `lib/data/services/resolved_cell_membership.dart` (override and computed paths).
- **`family`**: present in `lib/application/models/hive_cell_category.dart` as a **UI category**, not as a placement `cellId` in rules; people rules may consume **family cue keywords** — do not assume a `family` placement cell exists.

**Risk**: Debugging “memes” may require searching **three** ids: scoring winner may still be `animation_cartoon_meme` before normalization.

---

## 11. Standard Cursor prompt structure

Use this skeleton (matches `04_HIVE_DEBUGGING_RULES.md`):

1. **Goal** — one sentence.
2. **Files to inspect first** — absolute or repo-root paths; name **stage** + **symbol** (e.g. `_rejectPlaces`, `_applyDeterministicPrecedenceRules` branch).
3. **Observed vs expected** — cellIds, repro steps.
4. **Evidence** — labels, logs, fixture name if test-driven.
5. **Constraints** — no new pipeline stages; no broad threshold cuts; preserve explainability (`matchedKeywords` integrity per `04`).
6. **Tests** — default `test/keyword_placement_pipeline_test.dart` and/or `test/keyword_folder_mapping_service_test.dart`; add persistence tests if §9 issue.
7. **Validation** — `flutter analyze`; `flutter test` (name files).
8. **Report back** — root cause, minimal diff summary, tests, risks.

---

## 12. Validation checklist

After Cursor implements a fix:

- [ ] `flutter analyze` — zero issues (project standard).
- [ ] `flutter test` — at least affected files; full suite if touch shared helpers.
- [ ] New or updated test **asserts cellId** (and margin/gate reason if relevant).
- [ ] If routing changed: add case that would have **short-circuited** incorrectly.
- [ ] If sync/async touched: consider `test/persistence_reconciliation_test.dart` or coordinator tests.
- [ ] Manual smoke: one asset from bug report class (if device test not automated).

---

## 13. What NOT to ask Cursor without evidence

- “Fix placement globally” or “lower confidence everywhere.”
- “Reorder pipeline stages” (forbidden unless product explicitly requests).
- “Add keywords” without **real label/OCR/filename** examples from logs or fixtures.
- “Make X always win” without checking **routing early exit** and **precedence early returns**.
- Changes to **`animation_cartoon_meme`** without checking **§10** normalization and tests that assert final **display** cell.
- Swift/Kotlin/native Photos mutations — out of scope for typical placement work.

---

## Cross-references

- Architecture / stages: `docs/ai_context/02_HIVE_ARCHITECTURE_MAP.md`, `05_HIVE_CURRENT_STATE.md`
- Class index: `03_HIVE_CLASS_INDEX.md`
- Cursor template: `07_CURSOR_PROMPT_TEMPLATE.md`
