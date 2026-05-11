# HIVE — Architecture Map

This doc is a **high-signal map** of how HIVE works today so Claude can write precise prompts for Cursor.

## Runtime entry + navigation

- `lib/main.dart`
  - Reads `HIVE_CLASSIFICATION_BACKEND` compile-time env var.
  - Boots `MaterialApp` → `SplashScreen`.
  - Disposes shared MLKit resources on app dispose.

- `lib/presentation/screens/splash_screen.dart`
  - Loads settings + Photos permission status.
  - Routes to `OnboardingScreen` → `PermissionScreen` → `HomeScreen`.

## Main pipeline (end-to-end)

1. **Media asset loading**
   - `PhotoManagerMediaLibraryService` reads Apple Photos via `photo_manager`.
   - Supports scan scopes: full library, limited library, selected album/folder.

2. **ML labeling (classification)**
   - `ClassificationServiceFactory` chooses backend:
     - `IosVisionClassificationService` (Apple Vision via `MethodChannel`)
     - `GoogleMlKitClassificationService` (ML Kit plugin)
   - Outputs: `ClassificationOutcome` with `ClassificationLabel` list.

3. **Structural signal extraction**
   - `StructuralSignalExtractor` uses ML Kit detectors to extract:
     - face count + largest face area ratio
     - OCR text + text coverage ratio + layout hints (chat/table)
     - barcode/QR presence
     - MRZ pattern detection (passport/id)
   - Stored as `StructuralSignals`.

4. **Placement / routing / explainability**
   - `KeywordFolderMappingService` uses `KeywordPlacementPipeline`.
   - Pipeline stages (in order):
     1) `PlacementAnalysisBuilder`
     2) `ContentTypeRoutingStage`
     3) `WeightedCategoryScoringStage`
     4) `VetoPrecedenceStage`
     5) `CategoryEntryGateStage`
     6) `PlacementDecisionStage`
   - Output: `AssetMappingExplanation`
     - cellId/cellName/score
     - primaryEvidence / secondarySupport / fallbackOrDebugReasons
     - fallback reason + margin + runner-up context when Unsorted

5. **Persistence**
   - Local JSON snapshot store: `LocalScanResultStore` → `hive_scan_results.json`.
   - Repositories persist:
     - assets
     - folder cells
     - classification outcomes/labels
     - manual overrides
     - scan runs
     - placement audit entries

6. **Dashboard + folder membership resolution**
   - `PersistedHomeDashboardService` and `PersistedFolderDetailService` do **not** trust stale persisted membership.
   - They resolve each asset’s authoritative cell by:
     1) latest manual override (include-in-cell)
     2) latest placement audit entry (`finalCell`)
     3) placement mapping (`FolderMappingService.explainPlacement(...)`)

## Important classes and what they “own”

- `MediaAsset`: canonical asset record (id/type/dates/dimensions/filename).
- `ClassificationLabel`: normalized label + confidence + model id.
- `StructuralSignals`: OCR/face/layout/barcode/MRZ derived signals.
- `KeywordPlacementPipeline`: orchestrates stage-by-stage placement.
- `PlacementAnalysisBuilder`: converts asset+labels(+structural) → `AssetAnalysis`.
- `ContentTypeRoutingStage`: early deterministic routes (videos, receipts/docs, strong screenshot, mosque/architecture places, etc).
- `WeightedCategoryScoringStage`: base scoring + per-cell boosts.
- `VetoPrecedenceStage`: deterministic precedence + vetoes (memes/animation/books/docs/people conflicts).
- `CategoryEntryGateStage`: per-category “entry gates” that can veto weak placements.
- `PlacementDecisionStage`: final winner vs Unsorted using thresholds and margins.
- `RealScanCoordinator`: orchestrates scanning, progress events, caching reuse, persistence.

## Debug log markers used in code

These tags appear frequently in debug logs (when `kDebugMode`):

- `[HIVE-ENGINE]` — classifier backend selection and per-asset engine logging
- `[HIVE-ROUTE]`, `[HIVE-ROUTE-SELECT]`, `[HIVE-ROUTE-CHECK]` — deterministic routing checks/selections
- `[HIVE-SCORE]` — per-category scoring breakdown
- `[HIVE-PRECEDENCE]` — boosts/vetoes applied by precedence
- `[HIVE-GATE]` — category gate veto reasons
- `[HIVE-DECISION]` — ranked scores + margin decisions + Unsorted fallbacks
- `[HIVE-SCENE]` — place/nature decision debug summaries
- `[HIVE-FOOD]` — food stabilization/penalties
- `[HIVE-PASS-COMPARE]`, `[HIVE-PASS-MISMATCH]` — scan vs mapping pass comparison logs

